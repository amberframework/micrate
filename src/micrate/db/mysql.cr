module Micrate::DB
  class Mysql < Dialect
    def query_create_migrations_table(db)
      db.exec("CREATE TABLE micrate_db_version (
                id serial NOT NULL,
                version_id bigint NOT NULL,
                is_applied boolean NOT NULL,
                tstamp timestamp NULL default now(),
                PRIMARY KEY(id)
              );")
    end

    def query_migration_status(migration, db)
      db.query_all "SELECT tstamp, is_applied FROM micrate_db_version WHERE version_id=? ORDER BY tstamp DESC LIMIT 1", migration.version, as: {Time, Bool}
    end

    def query_record_migration(migration, is_applied, db)
      db.exec("INSERT INTO micrate_db_version (version_id, is_applied) VALUES (?, ?);", migration.version, is_applied)
    end
  end
end
