require "spectator"
require "spectator/should"
require "../src/micrate"
require "../src/cli"

# Do not run the application
module Micrate::Cli
  def self.run
    return
  end
end

# Hack to address issue #54 https://gitlab.com/arctic-fox/spectator/-/issues/54
FAKE_DB = [] of Spectator::Mocks::Double # Must be in top-level scope.
