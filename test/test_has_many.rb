require_relative 'helper'

describe 'has_many relation' do
  before do
    # testing hack
    [:Chapter, :Book, :Author].each {|k| Object.send(:remove_const, k) if Object.const_defined?(k)}

    Chapter = Class.new(Swift::Scheme) do
      store     :chapters
      attribute :id,      Integer, serial: true, key: true
      attribute :book_id, Integer
      attribute :name,    String
    end

    Book = Class.new(Swift::Scheme) do
      store     :books
      attribute :id,           Integer, serial: true, key: true
      attribute :author_id,    Integer
      attribute :name,         String
      has_many  :chapters
    end

    Author = Class.new(Swift::Scheme) do
      store     :authors
      attribute :id,   Integer, serial: true, key: true
      attribute :name, String
      has_many  :books
    end

    [Author, Book, Chapter].each {|klass| Swift.db.migrate! klass}
    @author = Author.create(name: 'Test User')
  end

  it 'should respond_to has_many accessors' do
    assert_respond_to @author, :books
    assert_respond_to @author, :books=
    assert_respond_to @author.class, :books
  end

  it 'should return HasMany relations with accessors' do
    assert_kind_of Swift::Associations::HasMany, @author.books
    assert_kind_of Swift::Associations::HasMany, @author.class.books
  end

  it 'should #create through relation' do
    assert_equal 0, @author.books.size
    assert @author.books.create(name: 'first book')
    assert_equal 0, @author.books.size               # cached
    assert_equal 1, @author.books.reload.size        # reloaded
  end

  it 'should append through relation' do
    assert_equal 0, @author.books.size
    assert @author.books << Book.new(name: 'book one')
    assert @author.books << Book.new(name: 'book two')
    assert_equal 2, @author.books.size
  end

  it 'should save children' do
    assert_equal 0, @author.books.size
    assert @author.books << Book.new(name: 'book one')
    assert @author.books << Book.new(name: 'book two')
    @author.save
    assert_equal 2, @author.books.reload.size
    assert_equal @author.id, @author.books[0].author_id
    assert_equal @author.id, @author.books[1].author_id
  end

  it 'should chain relations' do
    assert @author.books.create(name: 'book one')
    assert @author.books.create(name: 'book two')
    assert @author.books.chapters.create(name: 'book - chapter 1') # chapter in both books.
    assert @author.books.first.chapters.create(name: 'book one - chapter 2') # chapter in 1st book'

    assert_equal 3,                      @author.books.chapters.size
    assert_equal 'book - chapter 1',     @author.books[0].chapters[0].name
    assert_equal 'book one - chapter 2', @author.books[0].chapters[1].name
    assert_equal 'book - chapter 1',     @author.books[1].chapters[0].name
  end

  it 'should rollback changes if saving children fails' do
    db = Swift.db
    db.execute('drop table if exists books')
    db.execute('create table books (id integer primary key, author_id integer, name text not null)')

    author = Author.new(name: 'Kenny')
    author.books << Book.new

    assert_raises(SwiftRuntimeError) { author.save }
    assert_equal true, author.new?
    assert_equal true, author.books.first.new?

    assert_equal nil,  author.id
    assert_equal nil,  author.books.first.id

    # TODO we need to use swift/identity_map to allow appending created objects.
    @author.books << Book.new(name: 'test')
    @author.save

    @author.books << Book.new
    assert_equal false, @author.new?

    assert_raises(SwiftRuntimeError) { @author.save }
    assert_equal false, @author.new?
    assert_equal 1,     @author.id

    assert_equal true,  @author.books[1].new?
    assert_equal nil,   @author.books[1].id

    assert_equal false, @author.books[0].new?
    assert_equal 1,     @author.books[0].id
  end

  it 'should replace collection with new one using =' do
    assert @author.books.create(name: 'book 1')

    assert_equal 1,        @author.books.reload.size
    assert_equal 'book 1', @author.books.first.name

    @author.books = [ Book.new(name: 'book 2') ]
    @author.save

    assert_equal 1,        @author.books.reload.size
    assert_equal 'book 2', @author.books.first.name
  end

  it 'should lazy execute #all' do
    assert_kind_of Swift::Scheme::LazyAll, Author.all
    assert_equal   1, Author.all.rows
    assert_equal   0, Author.all(':name = ?', @author.name).books.size
  end
end
