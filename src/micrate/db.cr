module Micrate
  module DB
    @@connection_url : String?

    def self.connection_url=(connection_url)
      @@connection_url = connection_url
    end

    def self.connect
      PG.connect(@@connection_url.not_nil!)
    end

    def self.connect(&block)
      db = connect
      begin
        yield db
      ensure
        db.close
      end
    end

    def self.get_versions_last_first_order(db)
      db.exec({Int64, Bool}, "SELECT version_id, is_applied from micrate_db_version ORDER BY id DESC").rows
    end

    def self.create_migrations_table(db)
      db.exec("CREATE TABLE micrate_db_version (
                id serial NOT NULL,
                version_id bigint NOT NULL,
                is_applied boolean NOT NULL,
                tstamp timestamp NULL default now(),
                PRIMARY KEY(id)
              );")
    end

    def self.execute_migration(migration, direction, db)
      migration.statements(direction).each do |stmt|
        db.exec(stmt)
      end

      is_applied = direction == :forward
      db.exec("INSERT INTO micrate_db_version (version_id, is_applied) VALUES ($1, $2);", [migration.version, is_applied])
    end

    def self.get_migration_status(migration, db)
      rows = db.exec({Time, Bool}, "SELECT tstamp, is_applied FROM micrate_db_version WHERE version_id=$1 ORDER BY tstamp DESC LIMIT 1", [migration.version]).rows

      if !rows.empty? && rows[0][1]
        rows[0][0]
      else
        "Pending"
      end
    end
  end
end
