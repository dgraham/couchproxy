# encoding: UTF-8

$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__))

%w[
  em-http
  json
  json/stream
  thin
  time
  uri
  yaml
  zlib

  couchproxy/collator
  couchproxy/cluster
  couchproxy/node
  couchproxy/partition
  couchproxy/deferrable_body
  couchproxy/reducer
  couchproxy/request
  couchproxy/router

  couchproxy/rack/base
  couchproxy/rack/all_databases
  couchproxy/rack/bulk_docs
  couchproxy/rack/changes
  couchproxy/rack/compact
  couchproxy/rack/config
  couchproxy/rack/database
  couchproxy/rack/design_doc
  couchproxy/rack/doc
  couchproxy/rack/ensure_full_commit
  couchproxy/rack/not_found
  couchproxy/rack/replicate
  couchproxy/rack/revs_limit
  couchproxy/rack/root
  couchproxy/rack/stats
  couchproxy/rack/update
  couchproxy/rack/users
  couchproxy/rack/uuids
  couchproxy/rack/view_cleanup
].each {|f| require f }

module CouchProxy
  VERSION = '0.1.0'
end
