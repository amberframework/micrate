require "../../src/micrate"

def compile_micrate_runner_entry_points : Nil
  Micrate::DB.connection_url = "sqlite3::memory:"

  Micrate::DB.connect do |database|
    Micrate.up(database)
    Micrate.down(database)
  end

  Micrate::Cli.run
end

compile_micrate_runner_entry_points
