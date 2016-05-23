require "./micrate/*"
require "pg"

module Micrate

  @@connection_url : String?

  def self.connection_url=(conn_url)
    @@connection_url = conn_url
  end

  def self.db_dir
    "db"
  end

  def self.migrations_dir
    File.join(db_dir, "migrations")
  end

  def self.dbversion
    db = db_connect
    begin
      rows = db.exec({Int64, Bool}, "SELECT version_id, is_applied from micrate_db_version ORDER BY id DESC").rows
      return extract_dbversion(rows)
    rescue Exception
      db.exec("CREATE TABLE micrate_db_version (
                id serial NOT NULL,
                version_id bigint NOT NULL,
                is_applied boolean NOT NULL,
                tstamp timestamp NULL default now(),
                PRIMARY KEY(id)
              );")
      return 0
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

  protected def self.db_connect
    PG.connect(@@connection_url.not_nil!)
  end
end
