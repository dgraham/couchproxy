# encoding: UTF-8

require 'couchproxy'
require 'test/unit'

# Test that we properly sort JSON keys according to
# http://wiki.apache.org/couchdb/View_collation.
class CollatorTest < Test::Unit::TestCase
  def setup
    @collator = CouchProxy::Collator.new
  end

  def test_keyword
    assert_equal(0, @collator.compare(nil, nil))
    assert_equal(0, @collator.compare(true, true))
    assert_equal(0, @collator.compare(false, false))

    assert_equal(-1, @collator.compare(nil, false))
    assert_equal(1, @collator.compare(false, nil))

    assert_equal(-1, @collator.compare(nil, true))
    assert_equal(1, @collator.compare(true, nil))

    assert_equal(-1, @collator.compare(false, true))
    assert_equal(1, @collator.compare(true, false))
  end

  def test_number
    assert_equal(0, @collator.compare(0, 0))
    assert_equal(0, @collator.compare(0, 0.0))
    assert_equal(0, @collator.compare(1, 1.0))
    assert_equal(-1, @collator.compare(0, 1.0))
    assert_equal(1, @collator.compare(1.0, 0))
  end

  def test_string
    assert_equal(0, @collator.compare('', ''))
    assert_equal(0, @collator.compare('a', 'a'))
    assert_equal(-1, @collator.compare('a', 'aa'))
    assert_equal(-1, @collator.compare('a', 'b'))
    assert_equal(1, @collator.compare('b', 'a'))
  end

  def test_type
    assert_equal(-1, @collator.compare(nil, 0))
    assert_equal(-1, @collator.compare(nil, ''))
    assert_equal(-1, @collator.compare(nil, []))
    assert_equal(-1, @collator.compare(nil, {}))

    assert_equal(-1, @collator.compare(true, 0))
    assert_equal(-1, @collator.compare(true, ''))
    assert_equal(-1, @collator.compare(true, []))
    assert_equal(-1, @collator.compare(true, {}))

    assert_equal(-1, @collator.compare(false, 0))
    assert_equal(-1, @collator.compare(false, ''))
    assert_equal(-1, @collator.compare(false, []))
    assert_equal(-1, @collator.compare(false, {}))

    assert_equal(-1, @collator.compare(0, ''))
    assert_equal(-1, @collator.compare(0, []))
    assert_equal(-1, @collator.compare(0, {}))

    assert_equal(-1, @collator.compare('', []))
    assert_equal(-1, @collator.compare('', {}))

    assert_equal(-1, @collator.compare([], {}))
  end

  def test_array
    assert_equal(0, @collator.compare([], []))
    assert_equal(0, @collator.compare([0], [0]))
    assert_equal(0, @collator.compare([0], [0.0]))

    assert_equal(-1, @collator.compare([], [0]))
    assert_equal(-1, @collator.compare([0], [0, 1]))
    assert_equal(1, @collator.compare([0], []))
    assert_equal(1, @collator.compare([0, 1], [0]))

    assert_equal(1, @collator.compare([0], [-1, 0]))
    assert_equal(-1, @collator.compare([-1, 0], [0]))

    assert_equal(-1, @collator.compare([nil], [false]))
    assert_equal(-1, @collator.compare([nil], [nil, false]))

    assert_equal(0, @collator.compare([[]], [[]]))
    assert_equal(-1, @collator.compare([[0]], [[1]]))
    assert_equal(-1, @collator.compare([0], [[]]))
  end

  def test_hash
    assert_equal(0, @collator.compare({}, {}))
    assert_equal(0, @collator.compare({nil => nil}, {nil => nil}))
    assert_equal(-1, @collator.compare({nil => nil}, {nil => true}))
    assert_equal(1, @collator.compare({nil => true}, {nil => nil}))
    assert_equal(-1, @collator.compare({'a' => 1}, {'a' => 2}))
    assert_equal(-1, @collator.compare({'b' => 2}, {'b' => 2, 'a' => 1}))
    assert_equal(-1, @collator.compare({'b' => 2, 'a' => 1}, {'b' => 2, 'c' => 2}))
  end
end
