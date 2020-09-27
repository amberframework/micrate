require "log"
require "pg"
require "mysql"
require "sqlite3"

require "./micrate"

Log.define_formatter Micrate::CliFormat, "#{message}" \
                                         "#{data(before: " -- ")}#{context(before: " -- ")}#{exception}"
Log.setup(:info, Log::IOBackend.new(formatter: Micrate::CliFormat))

Micrate::Cli.run
