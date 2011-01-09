require_relative 'helper'

describe 'belongs_to relation' do
  before do
    # testing hack
    [:Chapter, :Book, :Author].each {|k| Object.send(:remove_const, k) if Object.const_defined?(k)}

    Chapter = Class.new(Swift::Scheme) do
      store      :chapters
      attribute  :id,      Integer, serial: true, key: true
      attribute  :book_id, Integer
      attribute  :name,    String
      belongs_to :book
    end

    Book = Class.new(Swift::Scheme) do
      store      :books
      attribute  :id,           Integer, serial: true, key: true
      attribute  :author_id,    Integer
      attribute  :name,         String
      belongs_to :author
      has_many   :chapters
    end

    Author = Class.new(Swift::Scheme) do
      store     :authors
      attribute :id,   Integer, serial: true, key: true
      attribute :name, String
      has_many  :books
    end

    [Author, Book, Chapter].each {|klass| Swift.db.migrate! klass}

    @author = Author.create(name: 'Test User')
    @book   = @author.books.create(name: 'First Book')
  end

  it 'should respond_to belongs_to accessors' do
    assert_respond_to @book, :author
    assert_respond_to @book, :author=
    assert_respond_to @book.class, :authors
  end

  it 'should return BelongsTo relations with accessors' do
    assert_kind_of Author, @book.author
    assert_kind_of Swift::Associations::BelongsTo, Book.authors
  end

  it 'should #create through relation' do
    assert_equal 0, @author.books.chapters.size
    assert @author.books.chapters.create(name: 'first chapter')
    assert_equal 1, @author.books.chapters.reload.size
  end

  it 'should chain relations' do
    assert @author.books.create(name: 'book two').chapters.create(name: 'chapter one')
    assert book = Book.first(':name = ?', 'book two')

    assert_equal 'chapter one', book.chapters.first.name
    assert_equal @author.name,  book.author.name
    assert_equal 2,             book.author.books.size
    assert_equal 0,             @book.chapters.size
    assert_equal 1,             @book.author.books.chapters.size
  end

  it 'should assign foreign key id via mutator' do
    assert book = Book.create(name: 'test', author: @author)
    assert_equal @author.id, book.author_id
  end
end
