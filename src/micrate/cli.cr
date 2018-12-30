require "option_parser"
require "logger"

module Micrate
  module Cli
    def self.run_exact(version : Int64, migrations_path, migrations_table_suffix)
      DB.connect do |db|
        Micrate.exact(db, version, migrations_path, migrations_table_suffix)
      end
    end

    def self.run_up(migrations_path, migrations_table_suffix)
      DB.connect do |db|
        Micrate.up(db, migrations_path, migrations_table_suffix)
      end
    end

    def self.run_down(migrations_path, migrations_table_suffix)
      DB.connect do |db|
        Micrate.down(db, migrations_path, migrations_table_suffix)
      end
    end

    def self.run_redo(migrations_path, migrations_table_suffix)
      DB.connect do |db|
        Micrate.redo(db, migrations_path, migrations_table_suffix)
      end
    end

    def self.run_status(migrations_path, migrations_table_suffix)
      DB.connect do |db|
        puts <<-MESSAGE
        Applied At                  Migration
        =====================================
        MESSAGE
        Micrate.migration_status(db, migrations_path, migrations_table_suffix).each do |migration, migrated_at|
          ts = migrated_at.nil? ? "Pending" : migrated_at.to_s
          puts "%-24s -- %s\n" % [ts, migration.name]
        end
      end
    end

    def self.run_create(migrations_path)
      if ARGV.size < 1
        raise "Migration name required"
      end

      migration_file = Micrate.create(ARGV.shift, Time.now, migrations_path)
      puts "Created #{migration_file}"
    end

    def self.run_dbversion(migrations_table_suffix)
      DB.connect do |db|
        begin
          puts Micrate.dbversion(db, migrations_table_suffix)
        rescue
          raise "Could not read dbversion. Please make sure the database exists and verify the connection URL."
        end
      end
    end

    def self.report_unordered_migrations(conflicting, migrations_path)
      puts "The following migrations haven't been applied but have a timestamp older then the current version:"
      conflicting.each do |version|
        puts "    #{Migration.from_version(migrations_path, version).name}"
      end
      puts <<-MESSAGE
      Micrate will not run these migrations because they may have been written with an older database model in mind.
      You should probably check if they need to be updated and rename them so they are considered a newer version."
      MESSAGE
    end

    def self.print_help
      puts <<-MESSAGE
      micrate is a database migration management system for Crystal projects, *heavily* inspired by Goose (https://bitbucket.org/liamstask/goose/).

      Usage:
        micrate [options] <subcommand> [-h] [subcommand options]

      Commands:
        up         Migrate the DB to the most recent version available
        down       Roll back the version by 1
        to         Migrate exact to the given version (e.g. micrate to -v 20160524162446)
        <version>  Shorthand for 'micrate to' (e.g. micrate 20160524162446)
        redo       Re-run the latest migration
        status     dump the migration status for the current DB
        create     Create the scaffolding for a new migration
        dbversion  Print the current version of the database
        help       Shows this message
      MESSAGE
    end

    def self.validate_command
      if ARGV.empty?
        print_help
        return
      end

      command = ARGV.shift

      unless ["up", "down", "redo", "status", "create", "dbversion", "help", "to"].includes?(command) || /^\d+$/.match(command)
        print_help
        exit 1
      end

      command
    end

    def self.parse_command_arguments
      migrations_path = Micrate::DEFAULT_MIGRATIONS_PATH
      migrations_table_suffix = ""
      migration_version = nil

      OptionParser.parse! do |parser|
        parser.banner = "Valid arguments:"

        parser.on("-p NAME", "--path=PATH", "Specifies the directory where migrations are stored") { |path| migrations_path = path }
        parser.on("-s NAME", "--suffix=SUFFIX", "Specifies a a suffix migrations table") { |suffix| migrations_table_suffix = suffix }
        parser.on("-v VERSION", "--version=VERSION", "Specifies an exact version to migrate to") { |version| migration_version = version }
        parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }
      end

      if !Dir.exists?(migrations_path)
        puts "Directory #{migrations_path} does not exist"
        exit 1
      end

      {migrations_path, migrations_table_suffix, migration_version}
    end

    def self.run
      setup_logger

      command = validate_command

      migrations_path, migrations_table_suffix, version = parse_command_arguments

      begin
        case command
        when "up"
          run_up(migrations_path, migrations_table_suffix)
        when "down"
          run_down(migrations_path, migrations_table_suffix)
        when "redo"
          run_redo(migrations_path, migrations_table_suffix)
        when "status"
          run_status(migrations_path, migrations_table_suffix)
        when "create"
          run_create(migrations_path)
        when "dbversion"
          run_dbversion(migrations_table_suffix)
        when "to"
          if version
            run_exact(version.to_i64, migrations_path, migrations_table_suffix)
          else
            "An exact migration version must be specified! For example: micrate to -v 20160524162446"
          end
        when /^\d+$/
          run_exact(command.not_nil!.to_i64, migrations_path, migrations_table_suffix)
        when "help"
          print_help
        end
      rescue e : UnorderedMigrationsException
        report_unordered_migrations(e.versions, migrations_path)
        exit 1
      rescue e : Exception
        puts e.message
        exit 1
      end
    end

    def self.setup_logger
      Micrate.logger = Logger.new(STDOUT).tap do |l|
        l.level = Logger::INFO
        l.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
          io << message
        end
      end
    end
  end
end
