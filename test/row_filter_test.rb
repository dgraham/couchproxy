# encoding: UTF-8

require 'couchproxy'
require 'test/unit'

class RowFilterTest < Test::Unit::TestCase
  def setup
    @parser = JSON::Stream::Parser.new
    @filter = CouchProxy::RowFilter.new(@parser)
  end

  def test_total_rows
    total_rows = -1
    @filter.total_rows {|total| total_rows = total }
    @parser << {:total_rows => 2, :offset => 0, :rows => [
        {:id => "1", :key => {:total_rows => 42}, :value => {:total_rows => 42}},
        {:id => "2", :key => {:total_rows => 42}, :value => {:total_rows => 42}}
      ]}.to_json
    assert_equal(2, total_rows)
  end

  def test_total_rows_missing
    total_rows = -1
    @filter.total_rows {|total| total_rows = total }
    @parser << {:offset => 0, :rows => [
        {:id => "1", :key => nil, :value => {:total_rows => 42}}
      ]}.to_json
    assert_equal(-1, total_rows)
  end

  def test_rows_with_small_dataset
    test_rows(3)
  end

  def test_rows_with_large_dataset
    test_rows(5003)
  end

  private

  def test_rows(count)
    all_rows = []
    @filter.rows {|rows| all_rows += rows }
    rows = Array.new(count) do |i|
      {:id => i.to_s, :key => {:rows => [42]}, :value => {:rows => [42]}}
    end
    @parser << {:total_rows => 2, :offset => 0, :rows => rows}.to_json
    assert_equal(count, all_rows.size)
    assert_equal(Array.new(count) {|i| i.to_s }, all_rows.map {|r| r['id'] })
  end
end