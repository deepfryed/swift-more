require 'etc'
require 'benchmark'
require 'dm-core'
require 'dm-migrations'

class Author
  include DataMapper::Resource
  storage_names[:default] = 'authors'
  property :id,   Serial
  property :name, String

  has n, :books
end # Author

class Book
  include DataMapper::Resource
  storage_names[:default] = 'books'
  property :id,        Serial
  property :name,      String
  property :author_id, Integer

  belongs_to :author
end

class Runner
  attr_reader :tests, :runs, :rows, :driver
  def initialize opts={}
    @driver  = opts[:driver] =~ /postgresql/ ? 'postgres' : opts[:driver]
    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end
    db = @driver == 'sqlite3' ? ':memory:' : 'swift'
    DataMapper.setup :default, {adapter: @driver, database: db, username: Etc.getlogin}
  end

  def run
    if tests.include? :create
      DataMapper.auto_migrate!
      yield run_creates
    end
    yield run_selects if tests.include? :select
    yield run_updates if tests.include? :update
  end

  def run_creates
    Benchmark.run("dm #create") do
      rows.times do |n|
        author = Author.create(name: "author #{n}")
        5.times do |m|
          author.books << Book.new(name: "book #{m}")
        end
        author.save
      end
    end
  end

  def run_selects
    Benchmark.run("dm #select") do
      runs.times do |n|
        Author.all(:id.lt => 100).books.each {|book| book.id }
      end
    end
  end

  def run_updates
    Benchmark.run("dm #update") do
      runs.times do
        Author.all(:name.like => 'author 1%').books.each {|book| book.update(name: 'book')}
      end
    end
  end
end
