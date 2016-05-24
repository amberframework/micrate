module Micrate
  class StatementBuilder
    @buffer : String::Builder

    def initialize
      @buffer = String::Builder.new
    end

    def write(s)
      @buffer.write(s.to_slice)
    end

    def reset
      @buffer = String::Builder.new
    end

    def to_s
      @buffer.to_s
    end
  end
end
