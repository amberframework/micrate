module Micrate::DB
  class Postgres < Dialect
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
      # The newest history row decides whether this migration counts as applied.
      # Sort by id, the order the rows were written, as `dbversion` does. tstamp
      # comes from a clock, and two rows can share a time or arrive out of order
      # when the server's clock is adjusted.
      db.query_all "SELECT tstamp, is_applied FROM micrate_db_version WHERE version_id=$1 ORDER BY id DESC LIMIT 1", migration.version, as: {Time, Bool}
    end

    def query_record_migration(migration, is_applied, db)
      db.exec("INSERT INTO micrate_db_version (version_id, is_applied) VALUES ($1, $2);", migration.version, is_applied)
    end
  end
end
