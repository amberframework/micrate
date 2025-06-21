require "colorize"

VERSION = `shards version lib/micrate`.strip

def micrate_executable
  {% if flag?(:windows) %}
    "bin/micrate-cli-#{VERSION}.exe"
  {% else %}
    "bin/micrate-cli-#{VERSION}"
  {% end %}
end

exe_path = Process.executable_path
abort("Failed to find micrate location") if exe_path.nil?

Dir.cd("#{Path.new(exe_path).dirname}/..")

unless File.exists?(micrate_executable)
  puts "Compiling micrate CLI...".colorize.green
  if !system("crystal build lib/micrate/src/micrate-cli.cr -o #{micrate_executable}")
    abort("Failed to compile micrate CLI.".colorize.red)
  end
end

Process.exec(micrate_executable, ARGV)
