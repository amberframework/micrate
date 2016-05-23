module Micrate
  module Cli
    def self.run_create
      if ARGV.size < 1
        puts "micrate create: migration name required"
        return
      end

      migration_file = Micrate.create(ARGV.shift, Micrate.db_dir, Time.now)

      puts "micrate: created #{migration_file}"
    end

    def self.run_up
      puts "TO-DO"
    end

    def self.run_down
      puts "TO-DO"
    end

    def self.run_dbversion
      puts "TO-DO"
    end

    def self.run
      case ARGV.shift
      when "create"
        run_create
      when "up"
        run_up
      when "down"
        run_down
      when "dbversion"
        run_dbversion
      else
        puts "invalid command"
      end
    end
  end
end
