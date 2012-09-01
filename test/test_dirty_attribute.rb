require 'helper'

describe 'dirty attribute tracking' do
  before do
    Object.send(:remove_const, :Author) if Object.const_defined?(:Author)

    Author = Class.new(Swift::Record) do
      store      :authors
      attribute  :id,           Integer, serial: true, key: true
      attribute  :name,         String
      attribute  :created_at,   DateTime, default: proc { DateTime.now }
    end

    Swift.db.migrate! Author
  end

  it 'should not update scheme when no change is recorded' do
    author = Author.create(name: 'author 1')
    io     = StringIO.new

    Swift.trace(io) do
      author.update(name: 'author 1')
    end

    io.rewind
    assert_equal "", io.read
  end

  it 'should update only the fields changed' do
    author = Author.create(name: 'author 1')
    io     = StringIO.new

    Swift.trace(io) do
      author.update(name: 'author 2')
    end

    io.rewind
    assert_match %r{set name = \? where id = \?}, io.read
  end
end
