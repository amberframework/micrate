require "./micrate/*"
require "pg"

module Micrate
  def self.db_dir
    "db"
  end

  def self.migrations_dir
    File.join(db_dir, "migrations")
  end

  def self.dbversion
    DB.connect do |db|
      begin
        rows = DB.get_versions_last_first_order(db)
        return extract_dbversion(rows)
      rescue Exception
        DB.create_migrations_table(db)
        return 0
      end
    end
  end

  def self.up
    DB.connect do |db|
      all_migrations = migrations_by_version
      current = dbversion
      target = all_migrations.keys.sort.last
      direction = current < target ? :forward : :backwards

      plan = migration_plan(all_migrations.keys, current, target, direction)

      if plan.empty?
        puts "micrate: no migrations to run. current version: #{current}"
        return
      end

      puts "micrate: migrating db, current version: #{current}, target: #{target}"

      plan.each do |version|
        migration = all_migrations[version]
        begin
          DB.execute_migration(migration, direction, db)
        rescue e : Exception
          puts "An error ocurred executing migration #{migration.version}. Error message is: #{e.message}"
          return
        end
      end
    end
  end

  def self.migrations_by_version
    Dir.entries(migrations_dir)
       .select { |name| File.file? File.join("db/migrations", name) }
       .select { |name| /^\d+_.+\.sql$/ =~ name }
       .map { |name| Migration.from_file(name) }
       .index_by { |migration| migration.version }
  end

  def self.migration_plan(all_migrations, current, target, direction)
    if direction == :forward
      all_migrations.sort
                    .select { |v| v > current && v <= target }
    else
      all_migrations.sort
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
end
