module Micrate::DB
  abstract class Dialect
    abstract def query_get_versions_last_first_order(db, migrations_table_suffix)
    abstract def query_create_migrations_table(db, migrations_table_suffix)
    abstract def query_migration_status(migration, db, migrations_table_suffix)
    abstract def query_record_migration(migration, is_applied, db, migrations_table_suffix)

    def self.from_connection_url(connection_url : String)
      uri = URI.parse(connection_url)
      case uri.scheme
      when "postgresql", "postgres"
        Postgres.new
      when "mysql"
        Mysql.new
      when "sqlite3"
        Sqlite3.new
      else
        raise "Could not infer SQL dialect from connection url #{connection_url}"
      end
    end

    def migrations_table_name(migrations_table_suffix)
      if migrations_table_suffix.size > 10 || !(/^[a-zA-Z0-9_]*$/.match migrations_table_suffix)
        # TODO: handle proper sanitization for each dialect. Until then, better be overly restrictive
        raise "Unsafe table name suffix. Only letters, numbers and underscores are allowed for the moment"
      else
        "micrate_db_version#{migrations_table_suffix}"
      end
    end
  end
end
