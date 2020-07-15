module Micrate
  class Migration
    SQL_CMD_PREFIX = "-- +micrate "

    getter version
    getter name
    getter source

    def initialize(@version : Int64, @name : String, @source : String)
    end

    # Algorithm ported from Goose
    #
    # Complex statements cannot be resolved by just splitting the script by semicolons.
    # In this cases we allow using StatementBegin and StatementEnd directives as hints.
    def statements(direction)
      return crystal_migration(direction) if name.ends_with?("cr")

      statements = [] of String

      # track the count of each section
      # so we can diagnose scripts with no annotations
      up_sections = 0
      down_sections = 0

      buffer = Micrate::StatementBuilder.new

      statement_ended = false
      ignore_semicolons = false
      direction_is_active = false

      source.split("\n").each do |line|
        if line.starts_with? SQL_CMD_PREFIX
          cmd = line[SQL_CMD_PREFIX.size..-1].strip
          case cmd
          when "Up"
            direction_is_active = direction == :forward
            up_sections += 1
          when "Down"
            direction_is_active = direction == :backwards
            down_sections += 1
          when "StatementBegin"
            if direction_is_active
              ignore_semicolons = true
            end
          when "StatementEnd"
            if direction_is_active
              statement_ended = ignore_semicolons == true
              ignore_semicolons = false
            end
          else
            # TODO? invalid command
          end
        end

        next unless direction_is_active

        buffer.write(line + "\n")

        if (!ignore_semicolons && ends_with_semicolon(line)) || statement_ended
          statement_ended = false
          statements.push buffer.to_s
          buffer.reset
        end
      end

      statements
    end

    def ends_with_semicolon(s)
      s.split("--")[0].strip.ends_with? ";"
    end

    def self.from_file(file_name)
      full_path = File.join(Micrate.migrations_dir, file_name)
      version = file_name.split("_")[0].to_i64
      new(version, file_name, File.read(full_path))
    end

    def self.from_version(version)
      file_name = Dir.entries(Micrate.migrations_dir)
        .find { |name| name.starts_with? version.to_s }
        .not_nil!
      self.from_file(file_name)
    end

    def crystal_migration(direction : Symbol)
      file_name = File.join(Micrate.migrations_dir, @name)
      io = IO::Memory.new
      if matcher = /^\d+_(.+).cr$/.match(@name)
        if class_name = matcher[1]
          if File.exists?(file_name)
            code = [] of String
            code << %(require "amber")
            code << %(require "granite/migration")
            code << %(require "./config/database.cr") if Dir.exists?("config")
            code << %(require "./#{file_name}")
            code << %(migration = #{class_name.camelcase}.new)
            code << %(puts migration.generate_sql(#{direction == :forward ? ":up" : ":down"}))
            Process.run(%(crystal eval '#{code.join("\n")}'), shell: true, output: io, error: io)
          end
        else
          Micrate.logger.error { "Could not find the class in file name: #{@name}.  Make sure the file name contains the name of the class to initialize." }
        end
      else
        Micrate.logger.error { "Could not match file name: #{@name}" }
      end
      sql = io.to_s
      Micrate.logger.info { sql }
      return sql.split(";")
    end
  end
end
