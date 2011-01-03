# encoding: UTF-8

# A source of rows that responds to EventMachine::Connection pause and resume
# methods. The reducer pauses sources to allow rows from slower connections
# to be read.
class MockSource
  attr_reader :uri

  def initialize(uri)
    @uri, @paused = uri, false
  end

  def pause
    @paused = true
  end

  def paused?
    @paused
  end

  def resume
    @paused = false
  end

  def ==(source)
    @uri == source.uri
  end

  def <=>(source)
    @uri <=> source.uri
  end
end