# encoding: UTF-8

require 'couchproxy'
require 'test/unit'

class ReduceReducerTest < Test::Unit::TestCase
  def setup
    @collator = CouchProxy::Collator.new
  end

  def test_sum
    reducer = CouchProxy::Reduce::ReduceReducer.new(
      :sources => %w[1 2], :collator => @collator, :fn => '_sum')
    rows, complete = [], []
    reducer.results {|results| rows += results }
    reducer.complete { complete << 1 }
    reducer.reduce([{'key' => 'a', 'value' => 2}], '2', false)
    reducer.reduce([{'key' => 'a', 'value' => 4}], '1', false)
    reducer.reduce([{'key' => 'c', 'value' => 6}], '1', true)
    reducer.reduce([{'key' => 'b', 'value' => 8}], '2', true)
    assert_equal(1, complete.inject(:+))
    assert(reducer.complete?)
    assert_equal(3, rows.size)
    results = rows.map {|r| r.values_at(:key, :value) }.flatten
    assert_equal(['a', 6, 'b', 8, 'c', 6], results)
  end

  def test_stats
    reducer = CouchProxy::Reduce::ReduceReducer.new(
      :sources => %w[1 2], :collator => @collator, :fn => '_stats')
    rows, complete = [], []
    reducer.results {|results| rows += results }
    reducer.complete { complete << 1 }
    values = [
      {'sum' => 2, 'count' => 3, 'min' => 0, 'max' => 2, 'sumsqr' => 1},
      {'sum' => 4, 'count' => 6, 'min' => 1, 'max' => 3, 'sumsqr' => 2},
      {'sum' => 2, 'count' => 3, 'min' => 0, 'max' => 2, 'sumsqr' => 3},
      {'sum' => 2, 'count' => 3, 'min' => 0, 'max' => 2, 'sumsqr' => 4}
    ]
    reducer.reduce([{'key' => 'a', 'value' => values[0]}], '2', false)
    reducer.reduce([{'key' => 'a', 'value' => values[1]}], '1', false)
    reducer.reduce([{'key' => 'c', 'value' => values[2]}], '1', true)
    reducer.reduce([{'key' => 'b', 'value' => values[3]}], '2', true)
    assert_equal(1, complete.inject(:+))
    assert(reducer.complete?)
    assert_equal(3, rows.size)
    results = rows.map {|r| r.values_at(:key, :value) }.flatten
    combined = {:sum => 6, :count => 9, :min => 0, :max => 3, :sumsqr => 3}
    assert_equal(['a', combined, 'b', to_sym(values[3]), 'c', to_sym(values[2])], results)
  end

  private

  def to_sym(hash)
    Hash[hash.map {|k,v| [k.to_sym, v]}]
  end
end