# encoding: UTF-8

require 'couchproxy'
require 'test/unit'

class MapReducerTest < Test::Unit::TestCase
  def setup
    @collator = CouchProxy::Collator.new
  end

  def test_no_rows_from_one_source
    reducer = CouchProxy::Reduce::MapReducer.new(
      :sources => ['1'], :collator => @collator)
    reducer.results do |results|
      flunk("No results expected")
    end
    complete = []
    reducer.complete { complete << 1 }
    reducer.reduce([], '1', true)
    assert_equal(1, complete.inject(:+))
    assert(reducer.complete?)
  end

  def test_no_rows_from_two_sources
    reducer = CouchProxy::Reduce::MapReducer.new(
      :sources => %w[1 2], :collator => @collator)
    reducer.results do |results|
      flunk("No results expected")
    end
    complete = []
    reducer.complete { complete << 1 }
    reducer.reduce([], '1', true)
    assert(!reducer.complete?)
    reducer.reduce([], '2', true)
    assert_equal(1, complete.inject(:+))
    assert(reducer.complete?)
  end

  def test_row_sorting
    reducer = CouchProxy::Reduce::MapReducer.new(
      :sources => ['1', '2'], :collator => @collator)
    rows, complete = [], []
    reducer.results {|results| rows += results }
    reducer.complete { complete << 1 }
    reducer.reduce([{'id' => '2', 'key' => 'a', 'value' => 'v2'}], '2', false)
    reducer.reduce([{'id' => '1', 'key' => 'a', 'value' => 'v1'}], '1', false)
    reducer.reduce([{'id' => '3', 'key' => 'c', 'value' => 'v4'}], '1', true)
    reducer.reduce([{'id' => '4', 'key' => 'b', 'value' => 'v3'}], '2', true)
    assert_equal(1, complete.inject(:+))
    assert(reducer.complete?)
    assert_equal(4, rows.size)
    assert_equal(%w[v1 v2 v3 v4], rows.map {|r| r['value'] })
  end

  def test_limit
    reducer = CouchProxy::Reduce::MapReducer.new(
      :sources => ['1', '2'], :collator => @collator, :limit => 2)
    rows, complete = [], []
    reducer.results {|results| rows += results }
    reducer.complete { complete << 1 }
    reducer.reduce([{'id' => '1', 'key' => 'a', 'value' => 'v1'}], '1', false)
    reducer.reduce([{'id' => '3', 'key' => 'c', 'value' => 'v4'}], '1', false)
    assert(!reducer.complete?)
    reducer.reduce([{'id' => '2', 'key' => 'a', 'value' => 'v2'}], '2', false)
    assert(reducer.complete?)
    reducer.reduce([{'id' => '4', 'key' => 'b', 'value' => 'v3'}], '2', false)
    assert_equal(1, complete.inject(:+))
    assert_equal(2, rows.size)
    assert_equal(%w[v1 v2], rows.map {|r| r['value'] })
  end

  def test_skip
    reducer = CouchProxy::Reduce::MapReducer.new(
      :sources => ['1', '2'], :collator => @collator, :skip => 2)
    rows, complete = [], []
    reducer.results {|results| rows += results }
    reducer.complete { complete << 1 }
    reducer.reduce([{'id' => '1', 'key' => 'a', 'value' => 'v1'}], '1', false)
    reducer.reduce([{'id' => '3', 'key' => 'c', 'value' => 'v4'}], '1', true)
    reducer.reduce([{'id' => '2', 'key' => 'a', 'value' => 'v2'}], '2', false)
    reducer.reduce([{'id' => '4', 'key' => 'b', 'value' => 'v3'}], '2', true)
    assert(reducer.complete?)
    assert_equal(1, complete.inject(:+))
    assert_equal(2, rows.size)
    assert_equal(%w[v3 v4], rows.map {|r| r['value'] })
  end
end