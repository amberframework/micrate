require "log"
require "spectator"
require "spectator/should"
require "../src/micrate"
require "../src/cli"

Log.setup(:error)

# Hack to address issue #54 https://gitlab.com/arctic-fox/spectator/-/issues/54
FAKE_DB = [] of Spectator::Mocks::Double # Must be in top-level scope.
