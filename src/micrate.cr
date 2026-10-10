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

    filename
  end

  @@connection_url : String? = ENV["DATABASE_URL"]?

  def self.connection_url : String?
    @@connection_url
  end

  def self.connection_url=(connection_url : String?)
    @@connection_url = connection_url
  end

  def self.default_runner : Runner
    Runner.new(@@connection_url)
  end

  def self.dbversion(db)
    default_runner.dbversion(db)
  end

  def self.up(db)
    default_runner.up(db)
  end

  def self.down(db)
    default_runner.down(db)
  end

  def self.redo(db)
    default_runner.redo(db)
  end

  def self.migration_status(db)
    default_runner.migration_status(db)
  end

  private def self.verify_unordered_migrations(current, status : Hash(Int, Bool))
    migrations = status.select { |version, is_applied| !is_applied && version < current }
      .keys

    if !migrations.empty?
      raise UnorderedMigrationsException.new(migrations)
    end
  end

  def self.previous_version(current, all_versions)
    all_previous = all_versions.select { |version| version < current }
    if !all_previous.empty?
      return all_previous.max
    end

    if all_versions.includes? current
      # the given version is (likely) valid but we didn't find
      # anything before it.
      # return value must reflect that no migrations have been applied.
      0
    else
      raise "no previous version found"
    end
  end

  def self.migrations_by_version
    Dir.entries(migrations_dir)
      .select { |name| File.file? File.join(migrations_dir, name) }
      .select { |name| /^\d+.+\.sql$/ =~ name }
      .map { |name| Migration.from_file(name) }
      .index_by(&.version)
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
        .sort!
        .select { |v| v > current && v <= target }
    else
      all_versions.keys
        .sort!
        .reverse!
        .select { |v| v <= current && v > target }
    end
  end

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

    0
  end

  class UnorderedMigrationsException < Exception
    getter :versions

    def initialize(@versions : Array(Int64))
      super()
    end
  end
end
