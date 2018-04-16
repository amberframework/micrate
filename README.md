> The Amber Team is currently working addressing Pending Issues, we will be notifying when a PR is ready for Community review.

# micrate

Micrate is a database migration tool written in Crystal.

It is inspired by [goose](https://bitbucket.org/liamstask/goose/). Some code was ported from there too, so check it out.

Micrate currently supports migrations for Postgres, Mysql and SQLite3, but it should be easy to add support for any other database engine with an existing [crystal-db API](https://github.com/crystal-lang/crystal-db) driver.

## Command line

Micrate runs as either a standalone binary that you "just run" to manipulate the database,
or you can call it from your Crystal code in the same way.

To use the Crystal API, add this to your application's `shard.yml`:

```yaml
dependencies:
  micrate:
    github: amberframework/micrate
```

This allows you to programatically use micrate's features. 
You'll see the `Micrate` module has an equivalent for every CLI command, so you can call those methods.
If you want to use micrate's CLI without installing the tool (which could be convenient in a CI environment) 
you can create a simple script like the following (we'll call it bin/micrate in this case):

```crystal
#! /usr/bin/env crystal

# Require your database's adapter
# require "pg"
# require "mysql"
# require "sqlite3"

require "micrate"

Micrate::Cli.run
```

...and use it just as the binary program (after `chmod +x`ing it):
```
$ bin/micrate dbversion
0
```

## Usage

Execute `micrate help` for usage instructions. Micrate will connect to the database specified by the `DB_URL` environment variable.
ppage

To create a new migration use the `create` subcommand. For example, `micrate create add_users_table` will create a new SQL migration file with a name such as `db/migrations/20160524162446_add_users_table.sql` that looks like this:

```sql
-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
```

Comments that start with `+micrate` are interpreted by micrate when running your migrations. In this case, the `Up` and `Down` directives are used to indicate which SQL statements must be run when applying or reverting a migration. You can now go along and write your migration like this:

```sql
-- +micrate Up
CREATE TABLE users(id INT PRIMARY KEY, email VARCHAR NOT NULL);

-- +micrate Down
DROP TABLE users;
```
Now run it using `micrate up`. This command will execute all pending migrations:

```
$ micrate up
Migrating db, current version: 0, target: 20160524162947
OK   20160524162446_add_users_table.sql

$ micrate dbversion # at any time you can find out the current version of the database
20160524162446
```

If you ever need to roll back the last migration, you can do so by executing `micrate down`. There's also `micrate redo` which rolls back the last migration and applies it again. If you want to migrate to a specific version, execute `micrate to -v 20160524162446` or even `micrate 20160524162446` (for example). Last but not least: use `micrate status` to find out the state of each migration:

```
$ micrate status
Applied At                  Migration
=======================================
2016-05-24 16:31:07 UTC  -- 20160524162446_add_users_table.sql
Pending                  -- 20160524163425_add_address_to_users.sql
```

If using complex statements that might contain semicolons, you must give micrate a hint on how to split the script into separate statements. You can do this with `StatementBegin` and `StatementEnd` directives: (thanks [goose](https://bitbucket.org/liamstask/goose/) for this!)

```
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
-- +micrate StatementEnd
```

## API

To use the Crystal API, add this to your application's `shard.yml`:

```yaml
dependencies:
  micrate:
    github: amberframework/micrate
```

This allows you to programatically use micrate's features. You'll see the `Micrate` module has an equivalent for every CLI command. If you need to use micrate's CLI without installing the tool (which could be convenient in a CI environment), you can write a runner script as follows:

```crystal
#! /usr/bin/env crystal
#
# To build a standalone command line client, require the
# driver you wish to use and use `Micrate::Cli`.
#

require "micrate"
require "pg"

Micrate::DB.connection_url = "postgresql://..."
Micrate::Cli.run
```

## Contributing

1. Fork it ( https://github.com/amberframework/micrate/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [juanedi](https://github.com/juanedi)  - creator, maintainer
