require "log"
{% for db in %w(pg mysql sqlite3) %}
  {% if file_exists?("lib/" + db) %}
    require {{ db }}
  {% end %}
{% end %}

require "./micrate"

Log.define_formatter Micrate::CliFormat, "#{message}" \
                                         "#{data(before: " -- ")}#{context(before: " -- ")}#{exception}"
Log.setup(:info, Log::IOBackend.new(formatter: Micrate::CliFormat))

Micrate::Cli.run
