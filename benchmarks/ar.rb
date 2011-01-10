require_relative 'gems/environment'
require 'etc'
require 'pg'
require 'mysql2'
require 'i18n'
require 'active_support'
require 'active_record'

class Author < ActiveRecord::Base
  set_table_name 'authors'
  has_many :books
end # Author

class Book < ActiveRecord::Base
  set_table_name 'books'
  belongs_to :author
end # Book

class Runner
  attr_reader :tests, :driver, :runs, :rows
  def initialize opts={}
    @driver  = opts[:driver] =~ /mysql/ ? 'mysql2' : opts[:driver]

    %w(tests runs rows).each do |name|
      instance_variable_set("@#{name}", opts[name.to_sym])
    end

    db = @driver == 'sqlite3' ? ':memory:' : 'swift'
    ActiveRecord::Base.establish_connection adapter: @driver, host: '127.0.0.1', username: Etc.getlogin, database: db
  end

  def run
    migrate!
    yield run_creates
    yield run_selects
    yield run_updates
  end

  def migrate!
    orig_stdout = $stdout
    $stdout = open('/dev/null', 'w')
    ActiveRecord::Schema.define do
      execute 'drop table if exists books'
      execute 'drop table if exists authors'
      create_table :authors do |t|
        t.column :name, :string
      end

      create_table :books do |t|
        t.column :name,      :string
        t.column :author_id, :integer
      end
    end
    $stdout = orig_stdout
  end

  def run_creates
    Benchmark.run("ar #create") do
      rows.times do |n|
        author = Author.create(name: "author #{n}")
        author.books << Book.new(name: "book #{n}")
        author.save
      end
    end
  end

  def run_selects
    Benchmark.run("ar #select") do
      runs.times do
        Author.find(:all, include: :books).map(&:books).flatten.each {|book| book.id}
      end
    end
  end

  def run_updates
    Benchmark.run("ar #update") do
      runs.times do |n|
        Author.find(:all).each {|author| author.books.each {|book| book.update_attributes(name: 'book')}}
      end
    end
  end
end