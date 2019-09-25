require "db"
require "./db/*"

module Micrate
  module DB
    @@connection_url = ENV["DB_URL"]?

    def self.connection_url
      @@connection_url
    end

    def self.connection_url=(connection_url)
      @@dialect = nil
      @@connection_url = connection_url
    end

    def self.connect
      validate_connection_url
      ::DB.connect(@@connection_url.not_nil!)
    end

    def self.connect(&block)
      validate_connection_url
      ::DB.open @@connection_url.not_nil! do |db|
        yield db
      end
    end

    def self.get_versions_last_first_order(db, migrations_table_suffix)
      dialect.query_get_versions_last_first_order(db, migrations_table_suffix)
    end

    def self.create_migrations_table(db, migrations_table_suffix)
      dialect.query_create_migrations_table(db, migrations_table_suffix)
    end

    def self.record_migration(migration, direction, db, migrations_table_suffix)
      is_applied = direction == :forward
      dialect.query_record_migration(migration, is_applied, db, migrations_table_suffix)
    end

    def self.exec(statement, db)
      db.exec(statement)
    end

    def self.get_migration_status(migration, db, migrations_table_suffix) : Time?
      rows = dialect.query_migration_status(migration, db, migrations_table_suffix)

      if !rows.empty? && rows[0][1]
        rows[0][0]
      else
        nil
      end
    end

    private def self.dialect
      validate_connection_url
      @@dialect ||= Dialect.from_connection_url(@@connection_url.not_nil!)
    end

    private def self.validate_connection_url
      if !@@connection_url
        raise "No database connection URL is configured. Please set the DB_URL environment variable."
      end
    end
  end
end
