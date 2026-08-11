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
    # Amber's generators include milliseconds so several migrations created in
    # the same second retain a deterministic order. Micrate now emits the same
    # format while continuing to read historic second-resolution filenames.
    timestamp = time.to_utc.to_s("%Y%m%d%H%M%S%3N")
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

  private def self.verify_unordered_migrations(current, status : Hash(Int, Bool))
    current_order = version_order_key(current)
    migrations = status.select do |version, is_applied|
      !is_applied && version_order_key(version) < current_order
    end
      .keys

    if !migrations.empty?
      raise UnorderedMigrationsException.new(migrations)
    end
  end

  def self.previous_version(current, all_versions)
    current_order = version_order_key(current)
    all_previous = all_versions.select { |version| version_order_key(version) < current_order }
    if !all_previous.empty?
      return all_previous.max_by { |version| version_order_key(version) }
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

  def self.migrations_by_version(dir = migrations_dir)
    return {} of Int64 => Migration unless Dir.exists?(dir)

    Dir.entries(dir)
      .select { |name| File.file? File.join(dir, name) }
      .select { |name| /^\d+.+\.sql$/ =~ name }
      .map { |name| Migration.from_file(name, dir) }
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
        .sort_by! { |version| version_order_key(version) }
        .select do |version|
          version_order_key(version) > version_order_key(current) &&
            version_order_key(version) <= version_order_key(target)
        end
    else
      all_versions.keys
        .sort_by! { |version| version_order_key(version) }
        .reverse!
        .select do |version|
          version_order_key(version) <= version_order_key(current) &&
            version_order_key(version) > version_order_key(target)
        end
    end
  end

  # Micrate historically generated 14-digit second-resolution timestamps while
  # Amber generated 17-digit millisecond-resolution timestamps. Comparing the
  # raw integers makes every millisecond migration look newer than every
  # second-resolution migration, regardless of its actual date. Scale the
  # historic format only for ordering; the stored migration identity remains
  # unchanged for backwards compatibility.
  def self.version_order_key(version : Int) : Int64
    raw = version.to_i64
    raw.to_s.size == 14 ? raw * 1000 : raw
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
