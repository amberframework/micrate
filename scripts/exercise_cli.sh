#!/usr/bin/env bash
# Runs the real command-line tool through a whole migration lifecycle against
# the database named by DATABASE_URL, checking the version after every step.
#
# This script creates and drops that database.
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL to a database this script may create and drop}"

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
crystal_compiler="${CRYSTAL:-crystal}"
cli_binary="$repository_root/bin/micrate-cli"
first_migration_version=20260101000000
second_migration_version=20260102000000

mkdir -p "$repository_root/bin"
(cd "$repository_root" && "$crystal_compiler" build src/micrate-cli.cr -o "$cli_binary")

working_directory="$(mktemp -d)"
trap 'rm -rf "$working_directory"' EXIT
cd "$working_directory"
mkdir -p db/migrations

cat > "db/migrations/${first_migration_version}_create_authors.sql" <<'SQL'
-- +micrate Up
CREATE TABLE authors (id INTEGER PRIMARY KEY, full_name VARCHAR(200) NOT NULL);

-- +micrate Down
DROP TABLE authors;
SQL

cat > "db/migrations/${second_migration_version}_create_books.sql" <<'SQL'
-- +micrate Up
CREATE TABLE books (id INTEGER PRIMARY KEY, title VARCHAR(200) NOT NULL);
CREATE TABLE reviews (id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL);

-- +micrate Down
DROP TABLE reviews;
DROP TABLE books;
SQL

assert_database_version_is() {
  local expected_version="$1"
  local actual_version
  actual_version="$("$cli_binary" dbversion)"
  if [[ "$actual_version" != "$expected_version" ]]; then
    echo "Expected database version $expected_version, found $actual_version" >&2
    exit 1
  fi
  echo "Database version is $expected_version"
}

assert_pending_migration_count_is() {
  local expected_count="$1"
  local actual_count
  actual_count="$("$cli_binary" status | grep -c Pending || true)"
  if [[ "$actual_count" != "$expected_count" ]]; then
    echo "Expected $expected_count pending migrations, found $actual_count" >&2
    exit 1
  fi
  echo "Pending migrations: $expected_count"
}

"$cli_binary" create
assert_database_version_is 0
assert_pending_migration_count_is 2

"$cli_binary" up
assert_database_version_is "$second_migration_version"
assert_pending_migration_count_is 0

"$cli_binary" down
assert_database_version_is "$first_migration_version"
assert_pending_migration_count_is 1

"$cli_binary" redo
assert_database_version_is "$first_migration_version"
assert_pending_migration_count_is 1

"$cli_binary" up
assert_database_version_is "$second_migration_version"

"$cli_binary" down
"$cli_binary" down
assert_database_version_is 0
assert_pending_migration_count_is 2

"$cli_binary" drop
echo "Lifecycle passed against ${DATABASE_URL%%:*}"
