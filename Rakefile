require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/testtask'
require_relative 'lib/couchproxy'

spec = Gem::Specification.new do |s| 
  s.name = "couchproxy"
  s.version = CouchProxy::VERSION
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = "A proxy server for Apache CouchDB clusters."
  s.description = "CouchProxy is a simple proxy server that distributes reads and writes to a
cluster of Apache CouchDB servers so they appear to be a single huge database.
Documents are stored and retrieved from a particular CouchDB instance, using
consistent hashing of the document id. Map/reduce views are processed
concurrently on each CouchDB instance and merged together by the proxy before
returning the results to the client."
  s.email = "david.malcom.graham@gmail.com"
  s.homepage = "http://github.com/dgraham/couchproxy"
  s.authors = ["David Graham"]
  s.files = FileList['[A-Z]*', '{bin,lib,conf}/**/*']
  s.test_files = FileList["test/**/*"]
  s.executables = %w[couchproxy]
  s.require_path = "lib"
  s.add_dependency('em-http-request', '~> 0.3')
  s.add_dependency('json', '~> 1.5')
  s.add_dependency('json-stream', '~> 0.1')
  s.add_dependency('thin', '~> 1.2')
  s.add_dependency('rbtree', '~> 0.3')
  s.required_ruby_version = '>= 1.9.1'
end
 
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true 
end 

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = true
end

task :default => [:clobber, :test, :gem]
