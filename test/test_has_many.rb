require_relative 'helper'

class Chapter < Swift::Scheme
  store     :chapters
  attribute :id,   Integer, serial: true, key: true
  attribute :name, String
end

class Book < Swift::Scheme
  store     :books
  attribute :id,           Integer, serial: true, key: true
  attribute :author_id,    Integer
  attribute :name,         String
  has_many  :chapters
end

class Author < Swift::Scheme
  store     :authors
  attribute :id,   Integer, serial: true, key: true
  attribute :name, String
  has_many  :books
end

describe 'has_many relation' do
  before do
    Swift.migrate!
    @author = Author.create(name: 'Test User').first
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
end
