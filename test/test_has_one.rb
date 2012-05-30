require 'helper'

describe 'has_one relation' do
  before do
    # testing hack
    [:Book, :Author].each {|k| Object.send(:remove_const, k) if Object.const_defined?(k)}

    Book = Class.new(Swift::Scheme) do
      store      :books
      attribute  :id,           Integer, serial: true, key: true
      attribute  :author_id,    Integer
      attribute  :name,         String
      belongs_to :author
    end

    Author = Class.new(Swift::Scheme) do
      store     :authors
      attribute :id,   Integer, serial: true, key: true
      attribute :name, String
      has_one   :book
    end

    [Author, Book].each {|klass| Swift.db.migrate! klass}

    @author = Author.create(name: 'Test User')
  end

  it 'should respond_to has_one accessors' do
    assert_respond_to @author, :book
    assert_respond_to @author, :book=
    assert_respond_to @author.class, :books
  end

  it 'should save via Author' do
    @author.book = Book.new(name: 'First Book')
    assert @author.save
    assert_equal 'First Book', Author.get(id: @author.id).book.name
  end

  it 'should save via Book' do
    Book.create(name: 'first book', author: @author)
    assert_equal 'first book', Author.get(id: @author.id).book.name
  end

  it 'should also save Author if needed' do
    Book.new(name: 'next book', author: Author.new(name: 'second author')).save
    assert_equal 'next book', Author.first('name = ?', 'second author').book.name
  end

  it 'should also save Book if needed' do
    Author.new(name: 'third author', book: Book.new(name: 'another book')).save
    assert_equal 'third author', Author.get(id: 2).name
    assert_equal 'another book', Author.get(id: 2).book.name
  end

  it '#create supports has_one' do
    Author.create(name: 'third author', book: Book.new(name: 'another book'))
    assert_equal 'third author', Author.get(id: 2).name
    assert_equal 'another book', Author.get(id: 2).book.name
  end
end
