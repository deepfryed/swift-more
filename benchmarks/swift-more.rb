$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'benchmark'
require 'swift'
require 'swift/migrations'
require 'swift-more'

class Book < Swift::Scheme
  store     :books
  attribute :id,        Integer, key: true, serial: true
  attribute :name,      String
  attribute :author_id, Integer

  belongs_to :author
end

class Author < Swift::Scheme
  store     :authors
  attribute :id,   Integer, key: true, serial: true
  attribute :name, String

  has_many :books
end # Author

class Runner
  attr_reader :tests, :runs, :rows, :driver
  def initialize opts={}
    @driver = opts[:driver]
    klass = case @driver
      when /postgresql/ then Swift::DB::Postgres
      when /mysql/      then Swift::DB::Mysql
      when /sqlite3/    then Swift::DB::Sqlite3
    end

    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end

    Swift.setup :default, klass, db: @driver == 'sqlite3' ? ':memory:' : 'swift'
  end

  def run
    if tests.include? :create
      Swift.migrate!
      yield run_creates
    end
    yield run_selects if tests.include? :select
    yield run_updates if tests.include? :update
  end

  def run_creates
    Benchmark.run("swift-m #create") do
      rows.times do |n|
        author = Author.new(name: "author #{n}")
        5.times do |m|
          author.books << Book.new(name: "book #{m}")
        end
        author.save
      end
    end
  end

  def run_selects
    Benchmark.run("swift-m #select") do
      runs.times do
        Author.all(':id < ?', 100).books.each {|book| book.id }
      end
    end
  end

  def run_updates
    Benchmark.run("swift-m #update") do
      runs.times do
        Author.all(':name like ?', 'author 1%').books.each {|book| book.update(name: 'book')}
      end
    end
  end
end
