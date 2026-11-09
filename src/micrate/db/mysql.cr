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
      # A migration can have several history rows, and the newest one decides
      # whether it counts as applied. Sort by id because id is the order the rows
      # were written. This tstamp column stores whole seconds, so an apply and a
      # rollback in the same second tie, and MySQL can return either row. Reading
      # the wrong row makes `status` report the wrong state, and it feeds the
      # out-of-order check that can stop `up`.
      db.query_all "SELECT tstamp, is_applied FROM micrate_db_version WHERE version_id=? ORDER BY id DESC LIMIT 1", migration.version, as: {Time, Bool}
    end

    def query_record_migration(migration, is_applied, db)
      db.exec("INSERT INTO micrate_db_version (version_id, is_applied) VALUES (?, ?);", migration.version, is_applied)
    end
  end
end
