require "./micrate/*"

module Micrate
  def self.db_dir
    "db"
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
end
