# micrate

Micrate is a database migration tool written in crystal.

It is shamelessly inspired by [goose](https://bitbucket.org/liamstask/goose/). Much of the code was ported from there, so check it out.

This is still a work in progress!

## Installation

To install the standalone binary tool check out the releases page, or use homebrew:

```
$ brew tap juanedi/micrate
$ brew install micrate
```

To use the Crystal API, add this to your application's `shard.yml`:

```yaml
dependencies:
  micrate:
    github: juanedi/micrate
```

If you need to use micrate's CLI without installing the tool (which could be convenient in a CI environment) you can create a simple script like the following:

```crystal
#! /usr/bin/env crystal
require "micrate"

Micrate::Cli.run
```

...and use it just as the binary program (after `chmod +x`ing it):
```
$ bin/micrate dbversion
0
```

## Usage

Execute `micrate help` for usage instructions. Micrate will connect to the postgres database specified by the `PG_URL` environment variable. Support for other database engines and better configuration options is on the way!

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
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE users(id INT PRIMARY KEY, email VARCHAR NOT NULL);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE users;
```

Now run it using `micrate up`. This command will execute all pending migrations:

```
$ micrate up
micrate: migrating db, current version: 0, target: 20160524162947
OK   20160524162446_add_users_table.sql

$ micrate dbversion # at any time you can find out the current version of the database
20160524162446
```

If you ever need to roll back the last migration, you can do so by executing `micrate down`. There's also `micrate redo` which rolls back the last migration and applies it again. Last but not least: use `micrate status` to find out the state of each migration:

```
$ micrate status
micrate: status
    Applied At                  Migration
    =======================================
    2016-05-24 16:31:07 UTC  -- 20160524162446_add_users_table.sql
    Pending                  -- 20160524163425_add_address_to_users.sql
```

## Contributing

1. Fork it ( https://github.com/juanedi/micrate/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## TODOs

   * Support for other database engines (currently only postgres is supported)
   * Use common crystal API for DB access
   * Multiple environments (development, test, production)
   * Crystal DSL for database migrations

## Contributors

- [juanedi](https://github.com/juanedi)  - creator, maintainer
