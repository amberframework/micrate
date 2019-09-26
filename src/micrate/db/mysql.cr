module Micrate::DB
  class Mysql < Dialect
    def query_get_versions_last_first_order(db, migrations_table_suffix)
      table_name = migrations_table_name(migrations_table_suffix)

      db.query_all "SELECT version_id, is_applied from #{table_name} ORDER BY id DESC", as: {Int64, Bool}
    end

    def query_create_migrations_table(db, migrations_table_suffix)
      table_name = migrations_table_name(migrations_table_suffix)

      db.exec("CREATE TABLE #{table_name} (
                id serial NOT NULL,
                version_id bigint NOT NULL,
                is_applied boolean NOT NULL,
                tstamp timestamp NULL default now(),
                PRIMARY KEY(id)
              );")
    end

    def query_migration_status(migration, db, migrations_table_suffix)
      table_name = migrations_table_name(migrations_table_suffix)

      db.query_all "SELECT tstamp, is_applied FROM #{table_name} WHERE version_id=? ORDER BY tstamp DESC LIMIT 1", migration.version, as: {Time, Bool}
    end

    def query_record_migration(migration, is_applied, db, migrations_table_suffix)
      table_name = migrations_table_name(migrations_table_suffix)

      db.exec("INSERT INTO #{table_name} (version_id, is_applied) VALUES (?, ?);", migration.version, is_applied)
    end
  end
end
