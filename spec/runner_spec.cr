require "./spec_helper"
require "sqlite3"

Spectator.describe Micrate::Runner do
  it "runs, rolls back, and re-runs migrations from an explicit directory" do
    root = File.join(Dir.tempdir, "micrate-runner-#{Process.pid}-#{Random.rand(1_000_000)}")
    migrations_dir = File.join(root, "custom_migrations")
    database_path = File.join(root, "pets.db")
    database_url = "sqlite3:#{database_path}"

    begin
      Dir.mkdir_p(migrations_dir)
      migration = <<-SQL
        -- +micrate Up
        CREATE TABLE pets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        );

        -- +micrate Down
        DROP TABLE pets;
        SQL
      File.write(
        File.join(migrations_dir, "20260811120000000_create_pets.sql"),
        migration
      )

      runner = Micrate::Runner.new(database_url, migrations_dir)

      runner.connect { |db| runner.up(db) }
      ::DB.open(database_url) do |db|
        db.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'pets'").should eq(1_i64)
      end

      runner.connect { |db| runner.down(db) }
      ::DB.open(database_url) do |db|
        db.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'pets'").should eq(0_i64)
      end

      runner.connect { |db| runner.up(db) }
      runner.connect { |db| runner.redo(db) }
      ::DB.open(database_url) do |db|
        db.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'pets'").should eq(1_i64)
      end
    ensure
      FileUtils.rm_r(root) if Dir.exists?(root)
    end
  end
end
