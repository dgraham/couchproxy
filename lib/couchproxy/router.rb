# encoding: UTF-8

module CouchProxy
  class Router
    DB_NAME      = '[a-z]([a-z0-9_$()+-]|%2[489bBfF])*'.freeze
    ROOT         = ''.freeze
    UUIDS        = '_uuids'.freeze
    USERS        = '_users'.freeze
    STATS        = '_stats'.freeze
    REPLICATE    = '_replicate'.freeze
    ALL_DBS      = '_all_dbs'.freeze
    ACTIVE_TASKS = '_active_tasks'.freeze
    CONFIG       = /^(_config|_config\/.*)$/
    BULK_DOCS    = /^#{DB_NAME}\/_bulk_docs$/
    ALL_DOCS     = /^#{DB_NAME}\/_all_docs$/
    DESIGN_DOC   = /^#{DB_NAME}\/_design\/.+$/
    COMPACT      = /^#{DB_NAME}\/(_compact|_compact\/.*)$/
    VIEW_CLEANUP = /^#{DB_NAME}\/_view_cleanup$/
    TEMP_VIEW    = /^#{DB_NAME}\/_temp_view$/
    UPDATE       = /^#{DB_NAME}\/_update$/
    REVS_LIMIT   = /^#{DB_NAME}\/_revs_limit$/
    CHANGES      = /^#{DB_NAME}\/_changes$/
    FULL_COMMIT  = /^#{DB_NAME}\/_ensure_full_commit$/
    DATABASE     = /^#{DB_NAME}$/
    DOC          = /^#{DB_NAME}\/.+$/

    def initialize(cluster)
      @cluster = cluster
    end

    def call(env)
      request = ::Rack::Request.new(env)
      app = case env['REQUEST_PATH'][1..-1].chomp('/')
        when ROOT         then :root
        when UUIDS        then :uuids
        when CONFIG       then :config
        when USERS        then :users
        when STATS        then :stats
        when REPLICATE    then :replicate
        when ALL_DBS      then :all_databases
        when ACTIVE_TASKS then :active_tasks
        when BULK_DOCS    then :bulk_docs
        when ALL_DOCS     then :all_docs
        when DESIGN_DOC   then :design_doc
        when COMPACT      then :compact
        when VIEW_CLEANUP then :view_cleanup
        when TEMP_VIEW    then :temp_view
        when UPDATE       then :update
        when REVS_LIMIT   then :revs_limit
        when CHANGES      then :changes
        when FULL_COMMIT  then :ensure_full_commit
        when DATABASE     then :database
        when DOC          then :doc
        else :not_found
      end
      name = app.to_s.split('_').map {|n| n.capitalize }.join
      app = CouchProxy::Rack.const_get(name).new(request, @cluster)
      app.send(request.request_method.downcase)
      throw :async
    end
  end
end
