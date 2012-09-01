$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minitest/autorun'
require 'minitest/pretty'

require 'swift'
require 'swift/adapter/sqlite3'
require 'swift/migrations'
require 'swift-more'

Swift.setup :default, Swift::Adapter::Sqlite3, db: ':memory:'
