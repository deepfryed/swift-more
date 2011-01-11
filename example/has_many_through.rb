#!/usr/bin/ruby -Ilib

require 'pp'
require 'swift'
require 'swift/migrations'
require 'swift-more'

Swift.setup :default, Swift::DB::Sqlite3, db: ':memory:'

class Store < Swift::Scheme
  store      :stores
  attribute  :id,      Integer, serial: true, key: true
  attribute  :name,    String

  has_many :books, through: :stocks
end

class Stock < Swift::Scheme
  store      :stocks
  attribute  :id,       Integer, serial: true, key: true
  attribute  :store_id, Integer
  attribute  :book_id,  Integer

  belongs_to :store
  belongs_to :book
end

class Book < Swift::Scheme
  store      :books
  attribute  :id,   Integer, serial: true, key: true
  attribute  :name, String

  has_many   :stores, through: :stocks
end

Swift.migrate!

Swift.trace true

book = Book.create(name: 'test book')
book.stores << Store.new(name: 'store 1')
book.save
p book.stores.reload.first.name #=> 'store 1'

book = Book.create(name: 'another test book', stores: book.stores.all)
p book.stores.reload.first.name #=> 'store 1'
