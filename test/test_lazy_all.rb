require 'helper'

describe 'LazyAll' do
  before do
    @user = Class.new(Swift::Scheme) do
      store      :users
      attribute  :id,      Integer, serial: true, key: true
      attribute  :name,    String
    end

    Swift.db.migrate! @user
    Swift.db.write('users', %w(name), "foo\nbar\nbaz\n")
  end

  it 'should call all() on the scheme and dispatch target method' do
    assert_equal 3, @user.all.count
    assert_equal 2, @user.all('name in (?, ?)', 'foo', 'bar').count
  end

  it 'should yield to given block' do
    results = []
    @user.all {|r| results << r}
    assert_equal 3, results.size

    results.clear
    @user.all('name in (?, ?)', 'foo', 'bar') {|r| results << r}
    assert_equal 2, results.size

    results.clear
    @user.all('name in (?, ?)', 'foo', 'bar').each {|r| results << r}
    assert_equal 2, results.size
  end
end
