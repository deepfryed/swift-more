require 'helper'
require 'tempfile'

describe 'dirty attribute tracking' do
  before do
    Object.send(:remove_const, :Author) if Object.const_defined?(:Author)

    Author = Class.new(Swift::Scheme) do
      store      :authors
      attribute  :id,           Integer, serial: true, key: true
      attribute  :name,         String
      attribute  :created_at,   DateTime, default: proc { DateTime.now }
    end

    Swift.db.migrate! Author
  end

  it 'should not update scheme when no change is recorded' do
    author = Author.create(name: 'author 1')
    file   = Tempfile.new('swift-more')

    Swift.trace(true, file) do
      author.update(name: 'author 1')
    end

    file.rewind
    assert_equal "", file.read
  end

  it 'should update only the fields changed' do
    author = Author.create(name: 'author 1')
    file   = Tempfile.new('swift-more')
    Swift.trace(true, file) do
      author.update(name: 'author 2')
    end
    file.rewind
    assert_match %r{set name = \? where id = \?}, file.read
  end
end
