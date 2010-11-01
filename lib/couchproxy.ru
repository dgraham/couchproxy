# encoding: UTF-8

$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__))

require 'couchproxy'

def cluster
  yaml = ENV['COUCH_PROXY_CONFIG'] || ''
  unless File.exist?(yaml)
    raise ArgumentError.new('COUCH_PROXY_CONFIG must point to a couchproxy.yml file')
  end
  config = YAML.load_file(yaml)
  raise ArgumentError.new('must define node list') unless config['nodes']
  nodes = config['nodes'].map {|n| CouchProxy::Node.new(n['host'], n['partitions']) }
  reducers = config['reducers'] || 4
  couchjs = config['couchjs'] or raise ArgumentError.new('must define couchjs')
  raise ArgumentError.new("#{couchjs} must be executable") unless File.executable?(couchjs)
  mainjs = File.expand_path('../../share/couchdb/server/main.js', couchjs)
  raise ArgumentError.new("could not find #{mainjs}") unless File.exist?(mainjs)
  CouchProxy::Cluster.new(nodes, couchjs, reducers)
end

run CouchProxy::Router.new(cluster)
