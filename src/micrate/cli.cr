module Micrate
  module Cli
    def self.run_up
      puts "TO-DO"
    end

    def self.run_down
      puts "TO-DO"
    end

    def self.run_redo
      puts "TO-DO"
    end

    def self.run_status
      puts "TO-DO"
    end

    def self.run_create
      if ARGV.size < 1
        puts "micrate create: migration name required"
        return
      end

      migration_file = Micrate.create(ARGV.shift, Micrate.migrations_dir, Time.now)
      puts "micrate: created #{migration_file}"
    end

    def self.run_dbversion
      begin
        puts "micrate: dbversion #{Micrate.dbversion}"
      rescue
        puts "Could not read dbversion. Please make sure the database exists and verify the connection URL."
      end
    end

    def self.help
      "micrate is a database migration management system for Crystal projects, *heavily* inspired by Goose (https://bitbucket.org/liamstask/goose/).

Usage:
    micrate [options] <subcommand> [subcommand options]

Commands:
    up         Migrate the DB to the most recent version available
    down       Roll back the version by 1
    redo       Re-run the latest migration
    status     dump the migration status for the current DB
    create     Create the scaffolding for a new migration
    dbversion  Print the current version of the database
      "
    end

    def self.run
      if ARGV.empty?
        puts help
        return
      end

      case ARGV.shift
      when "up"
        run_up
      when "down"
        run_down
      when "redo"
        run_redo
      when "status"
        run_status
      when "create"
        run_create
      when "dbversion"
        run_dbversion
      else
        puts help
      end
    end
  end
end
