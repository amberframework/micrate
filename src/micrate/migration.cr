module Micrate
  class Migration
    getter version
    getter name
    getter source

    def initialize(@version : Int64, @name : String, @source : String)
    end

    def self.from_file(file_name)
      full_path = File.join(Micrate.migrations_dir, file_name)
      version = file_name.split("_")[0].to_i64
      new(version, name, File.read(full_path))
    end
  end
end
