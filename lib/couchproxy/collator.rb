# encoding: UTF-8

module CouchProxy

  # Implements the JSON sorting rules defined at
  # http://wiki.apache.org/couchdb/View_collation.
  class Collator

    def initialize(reverse=false)
      @reverse = reverse
    end

    def compare(a, b)
      klass = compare_class(a, b)
      val = case klass
        when 0
          case a
            when String then compare_string(a, b)
            when Array  then compare_array(a, b)
            when Hash   then compare_array(a.to_a, b.to_a)
            else a <=> b
          end
        else
          klass
        end
      @reverse ? val * -1 : val
    end

    private

    def compare_class(a, b)
      # optimize common case
      return 0 if a.class == b.class
      aix, bix = class_index(a), class_index(b)
      aix == bix ? 0 : aix < bix ? -1 : 1
    end

    def class_index(value)
      case value
        when NilClass   then 0
        when FalseClass then 1
        when TrueClass  then 2
        when Numeric    then 3
        when String     then 4
        when Array      then 5
        when Hash       then 6
      end
    end

    # FIXME Implement UCA sorting with ICU
    def compare_string(a, b)
      a <=> b
    end

    def compare_array(a, b)
      if a.size == b.size
        compare_same_size_array(a, b)
      elsif a.size < b.size
        val = compare_same_size_array(a, b[0, a.size])
        val == 0 ? -1 : val
      else
        val = compare_same_size_array(a[0, b.size], b)
        val == 0 ? 1 : val
      end
    end

    def compare_same_size_array(a, b)
      a.each_with_index do |el, ix|
        val = compare(el, b[ix])
        return val unless val == 0
      end
      0
    end
  end
end
