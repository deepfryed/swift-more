#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + '/../lib'

require 'pp'
require 'swift'
require 'swift/migrations'
require 'swift-more'

Swift.setup :default, Swift::DB::Sqlite3, db: ':memory:'

class Chapter < Swift::Scheme
  store      :chapters
  attribute  :id,      Integer, serial: true, key: true
  attribute  :book_id, Integer
  attribute  :name,    String
  belongs_to :book
end

class Author < Swift::Scheme
  store     :authors
  attribute :id,   Integer, serial: true, key: true
  attribute :name, String
  has_many  :books
end

class Book < Swift::Scheme
  store      :books
  attribute  :id,           Integer, serial: true, key: true
  attribute  :author_id,    Integer
  attribute  :name,         String
  belongs_to :author
  has_many   :chapters
end

Swift.migrate!
Swift.trace true # set to false if you dont want to see the SQL as they get executed.

author = Author.create(name: 'Dale Arthurton')

# creation via associations
author.books.create(name: "Dale's first book")

# appending children and saving parent
author.books << Book.new(name: 'The second book')
author.save

pp author.books.chapters.size        #-> 0

# creates chapters in both books
author.books.chapters.create(name: 'The first chapter')
pp author.books.chapters.size        #-> 0
pp author.books.chapters.reload.size #-> 2

# chain associations
author.books.create(name: 'The third book').chapters.create(name: 'chapter one')

book = author.books.reload[2]

pp book.chapters.first.name #-> 'chapter one'
pp book.author.name         #-> 'Dale Arthurton
pp book.author.books.size   #-> 3

pp author.books('books.id in (1,2)').chapters.map(&:name).uniq  #-> ['The first chapter']

# Scheme#all is lazy
pp Author.all('authors.name like ?', 'Dale%').map(&:name)
pp Author.all('authors.name like ?', 'Dale%').books.map(&:name)

Author.first.books.first.update(name: 'foo')
