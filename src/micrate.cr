require "./micrate/*"

module Micrate
  @@logger : Logger?

  DEFAULT_MIGRATIONS_PATH = File.join("db", "migrations")

  def self.dbversion(db, migrations_table_suffix = "")
    begin
      rows = DB.get_versions_last_first_order(db, migrations_table_suffix)
      return extract_dbversion(rows)
    rescue Exception
      DB.create_migrations_table(db, migrations_table_suffix)
      return 0
    end
  end

  def self.exact(db, target, migrations_path = DEFAULT_MIGRATIONS_PATH, migrations_table_suffix = "")
    all_migrations = migrations_by_version(migrations_path)
    current = dbversion(db, migrations_table_suffix)
    migrate(all_migrations, current, target, db, migrations_table_suffix)
  end

  def self.up(db, migrations_path = DEFAULT_MIGRATIONS_PATH, migrations_table_suffix = "")
    all_migrations = migrations_by_version(migrations_path)

    current = dbversion(db, migrations_table_suffix)
    target = all_migrations.keys.sort.last
    migrate(all_migrations, current, target, db, migrations_table_suffix)
  end

  def self.down(db, migrations_path = DEFAULT_MIGRATIONS_PATH, migrations_table_suffix = "")
    all_migrations = migrations_by_version(migrations_path)

    current = dbversion(db, migrations_table_suffix)
    target = previous_version(current, all_migrations.keys)
    migrate(all_migrations, current, target, db, migrations_table_suffix)
  end

  def self.redo(db, migrations_path = DEFAULT_MIGRATIONS_PATH, migrations_table_suffix = "")
    all_migrations = migrations_by_version(migrations_path)

    current = dbversion(db, migrations_table_suffix)
    previous = previous_version(current, all_migrations.keys)

    migrate(all_migrations, current, previous, db, migrations_table_suffix)
    migrate(all_migrations, previous, current, db, migrations_table_suffix)
  end

  def self.migration_status(db, migrations_path = DEFAULT_MIGRATIONS_PATH, migrations_table_suffix = "") : Hash(Migration, Time?)
    # ensure that migration table exists
    dbversion(db, migrations_table_suffix)
    migration_status(migrations_by_version(migrations_path).values, db, migrations_table_suffix)
  end

  def self.migration_status(migrations : Array(Migration), db, migrations_table_suffix = "") : Hash(Migration, Time?)
    ({} of Migration => Time?).tap do |ret|
      migrations.each do |m|
        ret[m] = DB.get_migration_status(m, db, migrations_table_suffix)
      end
    end
  end

  def self.create(name, time, migrations_path = DEFAULT_MIGRATIONS_PATH)
    timestamp = time.to_s("%Y%m%d%H%M%S%L")
    filename = File.join(migrations_path, "#{timestamp}_#{name}.sql")

    migration_template = "\
-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
"

    Dir.mkdir_p migrations_path
    File.write(filename, migration_template)

    return filename
  end

  def self.connection_url=(connection_url)
    DB.connection_url = connection_url
  end

  # ---------------------------------
  # Private
  # ---------------------------------

  private def self.migrate(all_migrations : Hash(Int, Migration), current : Int, target : Int, db, migrations_table_suffix)
    direction = current < target ? :forward : :backwards

    status = migration_status(all_migrations.values, db, migrations_table_suffix)
    plan = migration_plan(status, current, target, direction)

    if plan.empty?
      logger.info "No migrations to run. current version: #{current}"
      return
    end

    logger.info "Migrating db, current version: #{current}, target: #{target}"

    plan.each do |version|
      migration = all_migrations[version]
      begin
        migration.statements(direction).each do |stmt|
          DB.exec(stmt, db)
        end

        DB.record_migration(migration, direction, db, migrations_table_suffix)

        logger.info "OK   #{migration.name}"
      rescue e : Exception
        logger.info "An error ocurred executing migration #{migration.version}. Error message is: #{e.message}"
        return
      end
    end
  end

  private def self.verify_unordered_migrations(current, status : Hash(Int, Bool))
    migrations = status.select { |version, is_applied| !is_applied && version < current }
                       .keys

    if !migrations.empty?
      raise UnorderedMigrationsException.new(migrations)
    end
  end

  private def self.previous_version(current, all_versions)
    all_previous = all_versions.select { |version| version < current }
    if !all_previous.empty?
      return all_previous.max
    end

    if all_versions.includes? current
      # the given version is (likely) valid but we didn't find
      # anything before it.
      # return value must reflect that no migrations have been applied.
      return 0
    else
      raise "no previous version found"
    end
  end

  private def self.migrations_by_version(migrations_path)
    Dir.entries(migrations_path)
       .select { |name| File.file? File.join(migrations_path, name) }
       .select { |name| /^\d+_.+\.sql$/ =~ name }
       .sort
       .map_with_index { |name, index| Migration.from_file(migrations_path, name, index) }
       .index_by { |migration| migration.version }
  end

  def self.migration_plan(status : Hash(Migration, Time?), current : Int, target : Int, direction)
    status = ({} of Int64 => Bool).tap do |h|
      status.each { |migration, migrated_at| h[migration.version] = !migrated_at.nil? }
    end

    migration_plan(status, current, target, direction)
  end

  def self.migration_plan(all_versions : Hash(Int, Bool), current : Int, target : Int, direction)
    verify_unordered_migrations(current, all_versions)

    if direction == :forward
      all_versions.keys
                  .sort
                  .select { |v| v > current && v <= target }
    else
      all_versions.keys
                  .sort
                  .reverse
                  .select { |v| v <= current && v > target }
    end
  end

  # The most recent record for each migration specifies
  # whether it has been applied or rolled back.
  # The first version we find that has been applied is the current version.
  def self.extract_dbversion(rows)
    to_skip = [] of Int64

    rows.each do |r|
      version, is_applied = r
      next if to_skip.includes? version

      if is_applied
        return version
      else
        to_skip.push version
      end
    end

    return 0
  end

  def self.logger
    @@logger ||= Logger.new(STDOUT).tap do |l|
      l.level = Logger::UNKNOWN
    end
  end

  def self.logger=(logger)
    @@logger = logger
  end

  class UnorderedMigrationsException < Exception
    getter :versions

    def initialize(@versions : Array(Int64))
      super()
    end
  end
end
