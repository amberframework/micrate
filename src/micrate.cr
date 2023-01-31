require "log"

require "./micrate/*"

module Micrate
  Log = ::Log.for(self)

  def self.db_dir
    "db"
  end

  def self.migrations_dir
    File.join(db_dir, "migrations")
  end

  def self.dbversion(db)
    begin
      rows = DB.get_versions_last_first_order(db)
      return extract_dbversion(rows)
    rescue Exception
      DB.create_migrations_table(db)
      return 0
    end
  end

  def self.up(db)
    all_migrations = migrations_by_version

    if all_migrations.size == 0
      Log.warn { "No migrations found!" }
      return
    end

    current = dbversion(db)
    target = all_migrations.keys.sort.last
    migrate(all_migrations, current, target, db)
  end

  def self.down(db)
    all_migrations = migrations_by_version

    current = dbversion(db)
    target = previous_version(current, all_migrations.keys)
    migrate(all_migrations, current, target, db)
  end

  def self.redo(db)
    all_migrations = migrations_by_version

    current = dbversion(db)
    previous = previous_version(current, all_migrations.keys)

    if migrate(all_migrations, current, previous, db) == :success
      migrate(all_migrations, previous, current, db)
    end
  end

  def self.migration_status(db) : Hash(Migration, Time?)
    # ensure that migration table exists
    dbversion(db)
    migration_status(migrations_by_version.values, db)
  end

  def self.migration_status(migrations : Array(Migration), db) : Hash(Migration, Time?)
    ({} of Migration => Time?).tap do |ret|
      migrations.each do |m|
        ret[m] = DB.get_migration_status(m, db)
      end
    end
  end

  def self.create(name, dir, time)
    timestamp = time.to_s("%Y%m%d%H%M%S")
    filename = File.join(dir, "#{timestamp}_#{name}.sql")

    migration_template = "\
-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
"

    Dir.mkdir_p dir
    File.write(filename, migration_template)

    return filename
  end

  def self.connection_url=(connection_url)
    DB.connection_url = connection_url
  end

  # ---------------------------------
  # Private
  # ---------------------------------

  private def self.migrate(all_migrations : Hash(Int, Migration), current : Int, target : Int, db)
    direction = current < target ? :forward : :backwards

    status = migration_status(all_migrations.values, db)
    plan = migration_plan(status, current, target, direction)

    if plan.empty?
      Log.info { "No migrations to run. current version: #{current}" }
      return :nop
    end

    Log.info { "Migrating db, current version: #{current}, target: #{target}" }

    plan.each do |version|
      migration = all_migrations[version]

      # Wrap migration in a transaction
      db.transaction do |tx|
        migration.statements(direction).each do |stmt|
          tx.connection.exec(stmt)
        end

        DB.record_migration(migration, direction, tx.connection)

        tx.commit
        Log.info { "OK   #{migration.name}" }
      rescue e : Exception
        tx.rollback
        Log.error(exception: e) { "An error occurred executing migration #{migration.version}." }
        return :error
      end
    end
    :success
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

  private def self.migrations_by_version
    Dir.entries(migrations_dir)
      .select { |name| File.file? File.join(migrations_dir, name) }
      .select { |name| /^\d+.+\.sql$/ =~ name }
      .map { |name| Migration.from_file(name) }
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

  class UnorderedMigrationsException < Exception
    getter :versions

    def initialize(@versions : Array(Int64))
      super()
    end
  end
end
