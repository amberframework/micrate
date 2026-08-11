require "db"
require "./db/*"

module Micrate
  class Runner
    getter connection_url : String
    getter migrations_dir : String

    def initialize(connection_url : String? = ENV["DATABASE_URL"]?,
                   @migrations_dir : String = Micrate.migrations_dir)
      url = connection_url
      if !url
        raise "No database connection URL is configured. Please set the DATABASE_URL environment variable."
      end
      @connection_url = url
    end

    def connect
      ::DB.connect(@connection_url)
    end

    def connect(&)
      ::DB.open(@connection_url) do |db|
        yield db
      end
    end

    def get_versions_last_first_order(db)
      db.query_all "SELECT version_id, is_applied from micrate_db_version ORDER BY id DESC", as: {Int64, Bool}
    end

    def create_migrations_table(db)
      dialect.query_create_migrations_table(db)
    end

    def record_migration(migration, direction, db)
      is_applied = direction == :forward
      dialect.query_record_migration(migration, is_applied, db)
    end

    def exec(statement, db)
      db.exec(statement)
    end

    def get_migration_status(migration, db) : Time?
      rows = dialect.query_migration_status(migration, db)

      rows[0][0] if !rows.empty? && rows[0][1]
    end

    private getter dialect : DB::Dialect do
      DB::Dialect.from_connection_url(@connection_url)
    end

    def dbversion(db)
      rows = get_versions_last_first_order(db)
      Micrate.extract_dbversion(rows)
    rescue Exception
      create_migrations_table(db)
      0
    end

    def up(db)
      all_migrations = Micrate.migrations_by_version(migrations_dir)

      if all_migrations.size == 0
        Log.warn { "No migrations found!" }
        return
      end

      current = dbversion(db)
      target = all_migrations.keys.max_by { |version| Micrate.version_order_key(version) }
      migrate(all_migrations, current, target, db)
    end

    def down(db)
      all_migrations = Micrate.migrations_by_version(migrations_dir)

      current = dbversion(db)
      target = Micrate.previous_version(current, all_migrations.keys)
      migrate(all_migrations, current, target, db)
    end

    def redo(db)
      all_migrations = Micrate.migrations_by_version(migrations_dir)

      current = dbversion(db)
      previous = Micrate.previous_version(current, all_migrations.keys)

      if migrate(all_migrations, current, previous, db) == :success
        migrate(all_migrations, previous, current, db)
      end
    end

    def migration_status(db) : Hash(Migration, Time?)
      # ensure that migration table exists
      dbversion(db)
      migration_status(Micrate.migrations_by_version(migrations_dir).values, db)
    end

    def migration_status(migrations : Array(Migration), db) : Hash(Migration, Time?)
      ({} of Migration => Time?).tap do |ret|
        migrations.each do |m|
          ret[m] = get_migration_status(m, db)
        end
      end
    end

    private def migrate(all_migrations : Hash(Int, Migration), current : Int, target : Int, db)
      direction = current < target ? :forward : :backwards

      status = migration_status(all_migrations.values, db)
      plan = Micrate.migration_plan(status, current, target, direction)

      if plan.empty?
        Log.info { "No migrations to run. current version: #{current}" }
        return :nop
      end

      Log.info { "Migrating db, current version: #{current}, target: #{target}" }

      plan.each do |version|
        migration = all_migrations[version]

        # Wrap migration in a transaction
        db.transaction do |tx|
          migration.statements(direction).each do |stmt|
            tx.connection.exec(stmt)
          end

          record_migration(migration, direction, tx.connection)

          tx.commit
          Log.info { "OK   #{migration.name}" }
        rescue e : Exception
          tx.rollback
          Log.error(exception: e) { "An error occurred executing migration #{migration.version}." }
          return :error
        end
      end
      :success
    end
  end
end
