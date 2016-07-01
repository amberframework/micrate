module Micrate
  module Cli
    def self.run_up
      DB.connect do |db|
        Micrate.up(db)
      end
    end

    def self.run_down
      DB.connect do |db|
        Micrate.down(db)
      end
    end

    def self.run_redo
      DB.connect do |db|
        Micrate.redo(db)
      end
    end

    def self.run_status
      DB.connect do |db|
        puts "micrate: status"
        puts "    Applied At                  Migration"
        puts "    ======================================="
        Micrate.migration_status(db).each do |migration, migrated_at|
          ts = migrated_at.nil? ? "Pending" : migrated_at.to_s
          puts "    %-24s -- %s\n" % [ts, migration.name]
        end
      end
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
      DB.connect do |db|
        begin
          puts "micrate: dbversion #{Micrate.dbversion(db)}"
        rescue
          puts "Could not read dbversion. Please make sure the database exists and verify the connection URL."
          exit 1
        end
      end
    end

    def self.report_unordered_migrations(conflicting)
      if !conflicting.empty?
        puts "The following migrations haven't been applied but have a timestamp older then the current version:"
        conflicting.each do |version|
          puts "    #{Migration.from_version(version).name}"
        end
        puts
        puts "Micrate will not run these migrations because they may have been written with an older database model in mind."
        puts "You should probably check if they need to be updated and rename them so they are considered a newer version."
        exit 1
      else
        puts "OK!"
        exit 0
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

      begin
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
      rescue e: UnorderedMigrationsException
        report_unordered_migrations(e.versions)
        exit 1
      rescue e: Exception
        puts e.message
        exit 1
      end

    end
  end
end
