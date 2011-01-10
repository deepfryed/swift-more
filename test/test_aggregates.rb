require_relative 'helper'

describe 'aggregate helpers' do
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
    @author.books.create(name: 'Book 1')
    @author.books.create(name: 'Book 2')

    @author.books.reload.chapters.create(name: 'Chapter 1')
    @author.books[1].chapters.create(name: 'Chapter 2')
  end

  it 'should count' do
    assert_equal 2, @author.books.count('books').execute[:books]
    assert_equal 1, @author.books(':name like ?', '%2').count.execute[:count]
  end

  it 'should min, max and sum' do
    assert_equal 2, @author.books.max('id').execute[:max_id]
    assert_equal 1, @author.books.min('id').execute[:min_id]
    assert_equal 3, @author.books.sum('id').execute[:sum_id]
  end

  it 'should group by etc.' do
    expect = [{count: 1, book_id: 1}, {count: 2, book_id: 2}]
    assert_equal expect, @author.books.chapters.count.execute(grouping: %w(book_id)).to_a
  end

  it 'should filter by having' do
    expect = [{chapters: 2, book_id: 2}]
    assert_equal expect, @author.books.chapters.count('chapters') # alias
                                      .execute(grouping: %w(book_id), having: 'chapters > 1').to_a
  end

  it 'should allow chaining' do
    assert_equal [1,2], @author.books.max(:id, 'max').min(:id, 'min').execute.values_at(:min, :max)
  end
end