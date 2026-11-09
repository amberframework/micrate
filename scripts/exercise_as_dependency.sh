#!/usr/bin/env bash
# Installs Micrate into a new application the way a user does, then runs the
# installed `bin/micrate` wrapper, which compiles the command-line tool on its
# first run from inside lib/micrate.
#
# This path differs from a compile inside this repository: the wrapper builds
# lib/micrate/src/micrate-cli.cr from the application's directory, using only
# the database drivers that application installed.
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
application_directory="$(mktemp -d)"
trap 'rm -rf "$application_directory"' EXIT

cd "$application_directory"
cat > shard.yml <<YAML
name: micrate_dependent_application
version: 0.1.0

dependencies:
  micrate:
    path: $repository_root
  sqlite3:
    github: crystal-lang/crystal-sqlite3
    version: "0.24.0"
    commit: 91f6c13d8f1df08f2659dfce7261ec9c40666302
YAML

# The repository's lock pins db and sqlite3 to exact, hash-verified versions.
cp "$repository_root/shard.lock" shard.lock
minecart install --skip-ai-docs --skip-ai-assistant

mkdir -p db/migrations
cat > db/migrations/20260101000000_create_authors.sql <<'SQL'
-- +micrate Up
CREATE TABLE authors (id INTEGER PRIMARY KEY);

-- +micrate Down
DROP TABLE authors;
SQL

export DATABASE_URL="sqlite3:$application_directory/application.sqlite3"
bin/micrate up

reported_version="$(bin/micrate dbversion | tail -n 1)"
if [[ "$reported_version" != "20260101000000" ]]; then
  echo "Expected version 20260101000000, found $reported_version" >&2
  exit 1
fi
echo "Micrate works as an installed dependency"
