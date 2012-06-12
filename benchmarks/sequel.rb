require 'bundler/setup'

require 'etc'
require 'sequel'
require 'logger'

class Runner
  attr_reader :tests, :driver, :runs, :rows

  def initialize opts = {}
    @driver  = case opts[:driver]
    when /mysql/
      'mysql2'
    when /postgres/
      'postgres'
    else
      opts[:driver]
    end

    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end

    if @driver == 'sqlite3'
      Object.const_set :DB, Sequel.sqlite
    else
      Object.const_set :DB, Sequel.connect(adapter: @driver, host: '127.0.0.1', user: Etc.getlogin, database: 'swift')
    end
  end

  def migrate!
    DB.execute 'drop table if exists books'
    DB.execute 'drop table if exists authors'
    DB.create_table :authors do
      primary_key :id
      String :name
    end
    DB.create_table :books do
      primary_key :id
      String  :name
      Integer :author_id
    end
  end

  def setup
    book = Class.new(Sequel::Model(:books)) do
      plugin :dataset_associations
    end

    author = Class.new(Sequel::Model(:authors)) do
      plugin :dataset_associations
      one_to_many :books, key: 'author_id'
    end

    Object.const_set :Book,   book
    Object.const_set :Author, author
  end

  def run
    migrate!          if tests.include?(:create)
    setup
    yield run_creates if tests.include?(:create)
    yield run_selects if tests.include?(:select)
    yield run_updates if tests.include?(:update)
  end

  def run_creates
    Benchmark.run("sequel #create") do
      rows.times do |n|
        author = Author.create(name: "author #{n}")
        5.times do |m|
          author.add_book(name: "book #{m}")
        end
      end
    end
  end

  def run_selects
    Benchmark.run("sequel #select") do
      runs.times { Author.filter("id < 100").books.each {|book| book.id }}
    end
  end

  def run_updates
    Benchmark.run("sequel #update") do
      runs.times do |n|
        Author.filter("name like 'author 1%'").books.each {|book| book.update(name: 'book')}
      end
    end
  end
end
