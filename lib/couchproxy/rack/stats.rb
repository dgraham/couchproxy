# encoding: UTF-8

module CouchProxy
  module Rack
    class Stats < Base
      def get
        proxy_to_all_nodes do |responses|
          docs = responses.map {|res| parse(res.response) }
          total = docs.shift.tap do |doc|
            each_stat(doc) do |group, name, values|
              %w[means stddevs].each {|k| values[k] = [values[k.chop]] }
            end
          end
          docs.each do |doc|
            each_stat(total) do |group, name, values|
              %w[current sum].each {|k| values[k] += doc[group][name][k] }
              %w[means stddevs].each {|k| values[k] << doc[group][name][k.chop] }
              %w[min max].each {|k| values[k] = [values[k], doc[group][name][k]].send(k) }
            end
          end
          each_stat(total) do |group, name, values|
            means, stddevs = %w[means stddevs].map {|k| values.delete(k) }
            mean = means.inject(:+) / means.size.to_f
            sums = means.zip(stddevs).map {|m, sd| m**2 + sd**2 }
            stddev = Math.sqrt(sums.inject(:+) / means.size.to_f - mean**2)
            mean, stddev = [mean, stddev].map {|f| sprintf('%.3f', f).to_f }
            values.update('stddev' => stddev, 'mean' => mean)
          end
          send_response(responses.first.response_header.status,
            response_headers, [total.to_json])
        end
      end

      private

      def parse(body)
        JSON.parse(body).tap do |doc|
          each_stat(doc) do |group, name, values|
            values.each {|k, v| values[k] = 0 unless v }
          end
        end
      end

      def each_stat(doc)
        doc.each do |group, stats|
          stats.each do |name, values|
            yield group, name, values
          end
        end
      end
    end
  end
end
