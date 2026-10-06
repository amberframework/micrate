require "../../src/micrate"

migration = Micrate::Migration.new(
  20261006020000_i64,
  "20261006020000_create_function.sql",
  <<-SQL
-- +micrate Up
-- +micrate StatementBegin
CREATE FUNCTION refresh_posts() RETURNS void AS $$
BEGIN
  PERFORM id FROM posts;
END;
$$ LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate Down
DROP FUNCTION refresh_posts();
SQL
)

list_of_up_statements : Array(String) = migration.statements(:forward)
list_of_down_statements : Array(String) = migration.statements(:backwards)
