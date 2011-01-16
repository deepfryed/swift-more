$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'benchmark'
require 'swift'
require 'swift/migrations'

class Book < Swift::Scheme
  store     :books
  attribute :id,        Swift::Type::Integer, key: true, serial: true
  attribute :name,      Swift::Type::String
  attribute :author_id, Swift::Type::Integer
end

class Author < Swift::Scheme
  store     :authors
  attribute :id,   Swift::Type::Integer, key: true, serial: true
  attribute :name, Swift::Type::String
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
    Swift.migrate!
    yield run_creates
    yield run_selects
    yield run_updates
  end

  def run_creates
    Benchmark.run("swift-v #create") do
      rows.times do |n|
        author = Author.create(name: "author #{n}").first
        book   = Book.create(name: "book #{n}", author_id: author.id).first
      end
    end
  end

  def run_selects
    Benchmark.run("swift-v #select") do
      stmt = Swift.db.prepare(Book, "select b.* from authors a join books b on (a.id = b.author_id)")
      runs.times do
        stmt.execute {|book| book.id }
      end
    end
  end

  def run_updates
    Benchmark.run("swift-v #update") do
      runs.times do
        Author.all.each {|author| Book.all('author_id = ?', author.id) {|book| book.update(name: 'book')}}
      end
    end
  end
end
