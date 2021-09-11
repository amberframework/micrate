require "log"

module Micrate
  module Cli
    Log = ::Log.for(self)

    def self.drop_database
      url = Micrate::DB.connection_url.to_s
      if url.starts_with? "sqlite3:"
        path = url.gsub("sqlite3:", "")
        File.delete(path)
        Log.info { "Deleted file #{path}" }
      else
        name = set_database_to_schema url
        Micrate::DB.connect do |db|
          db.exec "DROP DATABASE IF EXISTS #{name};"
        end
        Log.info { "Dropped database #{name}" }
      end
    end

    def self.create_database
      url = Micrate::DB.connection_url.to_s
      if url.starts_with? "sqlite3:"
        Log.info { "For sqlite3, the database will be created during the first migration." }
      else
        name = set_database_to_schema url
        Micrate::DB.connect do |db|
          db.exec "CREATE DATABASE #{name};"
        end
        Log.info { "Created database #{name}" }
      end
    end

    def self.set_database_to_schema(url)
      uri = URI.parse(url)
      if path = uri.path
        Micrate::DB.connection_url = url.gsub(path, "/#{uri.scheme}")
        path.gsub("/", "")
      else
        Log.error { "Could not determine database name" }
      end
    end

    def self.run_up
      Micrate::DB.connect do |db|
        Micrate.up(db)
      end
    end

    def self.run_down
      Micrate::DB.connect do |db|
        Micrate.down(db)
      end
    end

    def self.run_redo
      Micrate::DB.connect do |db|
        Micrate.redo(db)
      end
    end

    def self.run_status
      Micrate::DB.connect do |db|
        Log.info { "Applied At                  Migration" }
        Log.info { "=======================================" }
        Micrate.migration_status(db).each do |migration, migrated_at|
          ts = migrated_at.nil? ? "Pending" : migrated_at.to_s
          Log.info { "%-24s -- %s\n" % [ts, migration.name] }
        end
      end
    end

    def self.run_scaffold
      if ARGV.size < 1
        raise "Migration name required"
      end

      migration_file = Micrate.create(ARGV.shift, Micrate.migrations_dir, Time.local)
      Log.info { "Created #{migration_file}" }
    end

    def self.run_dbversion
      Micrate::DB.connect do |db|
        begin
          Log.info { Micrate.dbversion(db) }
        rescue
          raise "Could not read dbversion. Please make sure the database exists and verify the connection URL."
        end
      end
    end

    def self.report_unordered_migrations(conflicting)
      Log.info { "The following migrations haven't been applied but have a timestamp older then the current version:" }
      conflicting.each do |version|
        Log.info { "    #{Migration.from_version(version).name}" }
      end
      Log.info { "
Micrate will not run these migrations because they may have been written with an older database model in mind.
You should probably check if they need to be updated and rename them so they are considered a newer version." }
    end

    def self.print_help
      Log.info { "micrate is a database migration management system for Crystal projects, *heavily* inspired by Goose (https://bitbucket.org/liamstask/goose/).

Usage:
    set DATABASE_URL environment variable i.e. export DATABASE_URL=postgres://user:pswd@host:port/database
    micrate [options] <subcommand> [subcommand options]

Commands:
    create     Create the database (permissions required)
    drop       Drop the database (permissions required)
    up         Migrate the DB to the most recent version available
    down       Roll back the version by 1
    redo       Re-run the latest migration
    status     Dump the migration status for the current DB
    scaffold   Create the scaffolding for a new migration
    dbversion  Print the current version of the database" }
    end

    def self.run
      if ARGV.empty?
        print_help
        return
      end

      begin
        case ARGV.shift
        when "create"
          create_database
        when "drop"
          drop_database
        when "up"
          run_up
        when "down"
          run_down
        when "redo"
          run_redo
        when "status"
          run_status
        when "scaffold"
          run_scaffold
        when "dbversion"
          run_dbversion
        else
          print_help
        end
      rescue e : UnorderedMigrationsException
        report_unordered_migrations(e.versions)
        exit 1
      rescue e : Exception
        Log.error(exception: e) { "Micrate failed!" }
        exit 1
      end
    end
  end
end
