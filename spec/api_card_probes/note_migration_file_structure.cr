require "../../src/micrate"

migration = Micrate::Migration.new(
  20261006010000_i64,
  "20261006010000_create_posts.sql",
  <<-SQL
-- +micrate Up
CREATE TABLE posts(id INT PRIMARY KEY);

-- +micrate Down
DROP TABLE posts;
SQL
)

version : Int64 = migration.version
name : String = migration.name
source : String = migration.source
loaded_migration : Micrate::Migration = Micrate::Migration.from_file("20261006010000_create_posts.sql")
