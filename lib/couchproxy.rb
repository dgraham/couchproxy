# encoding: UTF-8

$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__))

module CouchProxy
  VERSION = '0.2.0'
end

%w[
  digest
  em-http
  json
  json/stream
  rbtree
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
  couchproxy/request
  couchproxy/router
  couchproxy/row_filter

  couchproxy/reducer
  couchproxy/reduce/base_reducer
  couchproxy/reduce/map_reducer
  couchproxy/reduce/reduce_reducer

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
