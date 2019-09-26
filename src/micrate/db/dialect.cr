module Micrate::DB
  abstract class Dialect
    abstract def query_create_migrations_table(db)
    abstract def query_migration_status(migration, db)
    abstract def query_record_migration(migration, is_applied, db)

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
  end
end
