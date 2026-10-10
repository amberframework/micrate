require "./spec_helper"

Spectator.describe Micrate do
  describe "splitting in statements" do
    it "split simple statements" do
      migration = Micrate::Migration.new(20160101120000, "foo.sql", "\
-- +micrate Up
CREATE TABLE foo(id INT PRIMARY KEY, name VARCHAR NOT NULL);

-- +micrate Down
DROP TABLE foo;")

      statements(migration, :forward).should eq([
        "-- +micrate Up\nCREATE TABLE foo(id INT PRIMARY KEY, name VARCHAR NOT NULL);",
      ])

      statements(migration, :backwards).should eq([
        "-- +micrate Down\nDROP TABLE foo;",
      ])
    end

    it "splits mixed Up and Down statements" do
      migration = Micrate::Migration.new(20160101120000, "foo.sql", "\
-- +micrate Up
CREATE TABLE foo(id INT PRIMARY KEY, name VARCHAR NOT NULL);

-- +micrate Down
DROP TABLE foo;

-- +micrate Up
CREATE TABLE bar(id INT PRIMARY KEY);

-- +micrate Down
DROP TABLE bar;")

      statements(migration, :forward).should eq([
        "-- +micrate Up\nCREATE TABLE foo(id INT PRIMARY KEY, name VARCHAR NOT NULL);",
        "-- +micrate Up\nCREATE TABLE bar(id INT PRIMARY KEY);",
      ])

      statements(migration, :backwards).should eq([
        "-- +micrate Down\nDROP TABLE foo;",
        "-- +micrate Down\nDROP TABLE bar;",
      ])
    end

    # Some complex PL/psql may have semicolons within them
    # To understand these we need StatementBegin/StatementEnd hints
    it "splits complex statements with user hints" do
      migration = Micrate::Migration.new(20160101120000, "foo.sql", "\
-- +micrate Up
-- +micrate StatementBegin
CREATE OR REPLACE FUNCTION histories_partition_creation( DATE, DATE )
returns void AS $$
DECLARE
  create_query text;
BEGIN
  FOR create_query IN SELECT
      'CREATE TABLE IF NOT EXISTS histories_'
      || TO_CHAR( d, 'YYYY_MM' )
      || ' ( CHECK( created_at >= timestamp '''
      || TO_CHAR( d, 'YYYY-MM-DD 00:00:00' )
      || ''' AND created_at < timestamp '''
      || TO_CHAR( d + INTERVAL '1 month', 'YYYY-MM-DD 00:00:00' )
      || ''' ) ) inherits ( histories );'
    FROM generate_series( $1, $2, '1 month' ) AS d
  LOOP
    EXECUTE create_query;
  END LOOP;  -- LOOP END
END;         -- FUNCTION END
$$
language plpgsql;
-- +micrate StatementEnd")

      ret = statements(migration, :forward)

      ret.size.should eq(1)
      ret[0].should eq(migration.source)
    end

    it "allows up and down sections with complex scripts" do
      migration = Micrate::Migration.new(20160101120000, "foo.sql", "\
-- +micrate Up
-- +micrate StatementBegin
foo;
bar;
-- +micrate StatementEnd

-- +micrate Down
baz;")

      statements(migration, :forward).should eq([
        "-- +micrate Up\n-- +micrate StatementBegin\nfoo;\nbar;\n-- +micrate StatementEnd",
      ])

      statements(migration, :backwards).should eq([
        "-- +micrate Down\nbaz;",
      ])
    end
  end

  describe ".from_version" do
    it "raises when migration version does not exist" do
      Dir.mkdir_p("db/migrations")
      expect_raises(Exception, "Migration 99999999999999 not found") do
        Micrate::Migration.from_version(99999999999999_i64)
      end
    end

    it "loads existing migration from version" do
      Dir.mkdir_p("db/migrations")
      test_file = "db/migrations/20260101000000_test.sql"
      File.write(test_file, "-- +micrate Up\n-- +micrate Down\n")
      begin
        migration = Micrate::Migration.from_version(20260101000000_i64)
        migration.version.should eq(20260101000000_i64)
        migration.name.should eq("20260101000000_test.sql")
      ensure
        File.delete(test_file) if File.exists?(test_file)
      end
    end
  end
end

def statements(migration, direction)
  migration.statements(direction).map(&.strip)
end
