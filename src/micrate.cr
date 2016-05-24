require "./micrate/*"
require "pg"

module Micrate

  @@connection_url : String?

  def self.connection_url=(conn_url)
    @@connection_url = conn_url
  end

  def self.db_dir
    "db"
  end

  def self.migrations_dir
    File.join(db_dir, "migrations")
  end

  def self.dbversion
    db = db_connect
    begin
      rows = db.exec({Int64, Bool}, "SELECT version_id, is_applied from micrate_db_version ORDER BY id DESC").rows
      return extract_dbversion(rows)
    rescue Exception
      db.exec("CREATE TABLE micrate_db_version (
                id serial NOT NULL,
                version_id bigint NOT NULL,
                is_applied boolean NOT NULL,
                tstamp timestamp NULL default now(),
                PRIMARY KEY(id)
              );")
      return 0
    end
  end

  def self.up
    db = db_connect

    all_migrations = files = Dir.entries("db/migrations")
                                .select   { |name| File.file? File.join("db/migrations", name) }
                                .select   { |name| /^\d+_.+\.sql$/ =~ name }
                                .map      { |name| Migration.from_file(name) }
                                .index_by { |migration| migration.version }

    current = dbversion
    target = all_migrations.keys.sort.last
    direction = current < target ? :forward : :backwards
    plan = migration_plan(all_migrations.keys, current, target, direction)

    if plan.empty?
      puts "micrate: no migrations to run. current version: #{current}"
      return
    end

    puts "micrate: migrating db, current version: #{current}, target: #{target}"

    plan.each do |version|
      migration = all_migrations[version]
      begin
        execute_migration(migration, direction, db)
      rescue e : Exception
        puts "An error ocurred executing migration #{migration.version}. Error message is: #{e.message}"
        return
      end
    end
  end

  def self.execute_migration(migration, direction, db)
    is_applied = direction == :forward
    statements(migration.source, is_applied).each do |stmt|
      db.exec(stmt)
    end
    db.exec("INSERT INTO micrate_db_version (version_id, is_applied) VALUES ($1, $2);", [migration.version, is_applied])
  end

  def self.statements(source, direction)
    statements = [] of String
    sql_cmd_prefix = "-- +micrate "
    
    # track the count of each section
    # so we can diagnose scripts with no annotations
    up_sections = 0
    down_sections = 0

    buffer = Micrate::StatementBuilder.new

    statement_ended = false
    ignore_semicolons = false
    direction_is_active = false

    source.split("\n").each do |line|
      if line.starts_with? sql_cmd_prefix
        cmd = line[sql_cmd_prefix.size..-1].strip
        case cmd
        when "Up"
          direction_is_active = direction == true
          up_sections += 1
        when "Down"
          direction_is_active = direction == false
          down_sections += 1
        when "StatementBegin"
          if direction_is_active
            ignore_semicolons = true
          end
        when "StatementEnd"
          if direction_is_active
            statement_ended = ignore_semicolons == true
            ignore_semicolons = false
          end
        end
      end

      next unless direction_is_active

      buffer.write(line + "\n")

      if (!ignore_semicolons && ends_with_semicolon(line)) || statement_ended
        statement_ended = false
        statements.push buffer.to_s
        buffer.reset
      end
    end

    statements
  end

  def self.ends_with_semicolon(s)
    s.split("--")[0].strip.ends_with? ";"
  end

  def self.migration_plan(all_migrations, current, target, direction)
    plan = all_migrations.sort

    if direction == :forward
      plan.select! { |v| v > current && v <= target }
    else
      plan.reverse!
          .select! { |v| v <= current && v > target }
    end

    plan
  end

  # The most recent record for each migration specifies
  # whether it has been applied or rolled back.
  # The first version we find that has been applied is the current version.
  def self.extract_dbversion(rows)
    to_skip = [] of Int64

    rows.each do |r|
      version, is_applied = r
      next if to_skip.includes? version

      if is_applied
        return version
      else
        to_skip.push version
      end
    end

    return 0
  end

  def self.create(name, dir, time)
    timestamp = time.to_s("%Y%m%d%H%M%S")
    filename = File.join(dir, "#{timestamp}_#{name}.sql")

    migration_template = "\
-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
"

    Dir.mkdir_p dir
    File.write(filename, migration_template)

    return filename
  end

  protected def self.db_connect
    PG.connect(@@connection_url.not_nil!)
  end
end
