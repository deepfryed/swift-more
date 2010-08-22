#!/usr/bin/env ruby

$:.unshift 'lib'
$:.unshift '../swift/lib'

require 'pp'
require 'swift'
require 'swift/migrations'
require 'swift/associations'

class Publisher < Swift::Scheme
  store     :publishers
  attribute :id,   Swift::Type::Integer, serial: true, key: true
  attribute :name, Swift::Type::String

  has_many :books
end

class Book < Swift::Scheme
  store     :books
  attribute :id,           Swift::Type::Integer, serial: true, key: true
  attribute :author_id,    Swift::Type::Integer
  attribute :publisher_id, Swift::Type::Integer
  attribute :name,         Swift::Type::String

  belongs_to :publisher
  belongs_to :author
end

class Author < Swift::Scheme
  store     :authors
  attribute :id,   Swift::Type::Integer, serial: true, key: true
  attribute :name, Swift::Type::String

  has_many :books
end # User

adapter = ARGV.first =~ /mysql/i ? Swift::DB::Mysql : Swift::DB::Postgres
puts "Using DB: #{adapter}"

Swift.setup :default, adapter, db: 'swift'
Swift.trace true

puts '-- migrate! --'
Swift.migrate!

puts '', '-- create --'
Author.create name: 'Apple Arthurton'

puts '', '-- get --'
pp author = Author.get(id: 1)

puts '', '-- create association --'
author.books.create(name: 'A day in the life of Arthurtons')

puts '', '-- fetch association --'
pp author.books(':name like ?', '%life%').all

publisher = Publisher.create(name: 'The Kaui Mai Press').first
author.books.first.update(publisher_id: publisher.id)

pp author.books.publishers.all
