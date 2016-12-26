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

    def self.get_versions_last_first_order(db)
      db.query_all "SELECT version_id, is_applied from micrate_db_version ORDER BY id DESC", as: {Int64, Bool}
    end

    def self.create_migrations_table(db)
      dialect.query_create_migrations_table(db)
    end

    def self.record_migration(migration, direction, db)
      is_applied = direction == :forward
      dialect.query_record_migration(migration, is_applied, db)
    end

    def self.exec(statement, db)
      db.exec(statement)
    end

    def self.get_migration_status(migration, db) : Time?
      rows = dialect.query_migration_status(migration, db)

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
