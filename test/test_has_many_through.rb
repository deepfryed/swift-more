require 'helper'

describe 'has_many through relation' do
  before do
    # testing hack
    [:Store, :Stock, :Book].each {|k| Object.send(:remove_const, k) if Object.const_defined?(k)}

    Store = Class.new(Swift::Record) do
      store      :stores
      attribute  :id,      Integer, serial: true, key: true
      attribute  :name,    String

      has_many :books, through: :stocks
    end

    Stock = Class.new(Swift::Record) do
      store      :stocks
      attribute  :id,       Integer, serial: true, key: true
      attribute  :store_id, Integer
      attribute  :book_id,  Integer

      belongs_to :store
      belongs_to :book
    end

    Book = Class.new(Swift::Record) do
      store      :books
      attribute  :id,   Integer, serial: true, key: true
      attribute  :name, String

      has_many   :stores, through: :stocks
    end

    [Store, Stock, Book].each {|klass| Swift.db.migrate! klass}

    @book = Book.create(name: 'test book')
  end

  it 'should create child objects via #save' do
    @book.stores << Store.new(name: 'store 1')
    assert @book.save
    assert_equal 'store 1', @book.stores.reload.first.name

    Store.get(id: 1).update(name: 'store 2')

    # cached
    assert_equal 'store 1', @book.stores.first.name
    # uncached
    assert_equal 'store 2', @book.stores.reload.first.name
  end

  it 'should accept persisted objects' do
    @book.stores << Store.create(name: 'store 1')
    assert @book.save
    assert_equal 'store 1', @book.stores.reload.first.name
  end

  it 'should create child objects via #create' do
    book = Book.create(name: 'sample book', stores: [Store.new(name: 'sample store')])
    assert book.persisted
    assert_equal 'sample store', Book.all(':name = ?', 'sample book').stores.first.name
  end

  it 'should raise an exception when passed a wrong type' do
    assert_raises(Swift::ArgumentError) { @book.stores << Book.create(name: 'test book') }
  end
end
