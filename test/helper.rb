$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minitest/autorun'
require 'minitest/pride' if $stdout.tty?

require 'swift'
require 'swift/migrations'
require 'swift-more'

Swift.setup :default, Swift::DB::Sqlite3, db: ':memory:'
