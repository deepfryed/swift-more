Swift More
==========

* http://github.com/deepfryed/swift-more

## Description

Experimental extensions to [Swift ORM](https://github.com/shanna/swift).

## Dependencies

* ruby   >= 1.9.1
* swift  >= 0.14.0

# Features

* Associations: 1:1, 1:N, M:N
* Dirty attribute tracking for updates

## Synopsis

```ruby
  require 'pp'
  require 'swift'
  require 'swift/migrations'
  require 'swift-more'

  Swift.setup :default, Swift::DB::Sqlite3, db: ':memory:'

  class Chapter < Swift::Record
    store      :chapters
    attribute  :id,      Integer, serial: true, key: true
    attribute  :book_id, Integer
    attribute  :name,    String
    belongs_to :book
  end

  class Book < Swift::Record
    store      :books
    attribute  :id,           Integer, serial: true, key: true
    attribute  :author_id,    Integer
    attribute  :name,         String
    belongs_to :author
    has_many   :chapters
  end

  class Author < Swift::Record
    store     :authors
    attribute :id,   Integer, serial: true, key: true
    attribute :name, String
    has_many  :books
  end

  Swift.migrate!
  Swift.trace false # swift to true if you want to see the SQL as they get executed.

  author = Author.create(name: 'Dale Arthurton')

  # creation via association
  author.books.create(name: "Dale's first book")

  # appending children and saving parent
  author.books << Book.new(name: 'The second book')
  author.save

  pp author.books.chapters.size        #=> 0

  # creates chapters in both books
  author.books.chapters.create(name: 'The first chapter')
  pp author.books.chapters.size        #=> 0
  pp author.books.chapters.reload.size #=> 2

  # chain associations
  author.books.create(name: 'The third book').chapters.create(name: 'chapter one')

  book = author.books.reload[2]

  pp book.chapters.first.name #=> 'chapter one'
  pp book.author.name         #=> 'Dale Arthurton
  pp book.author.books.size   #=> 3

  pp author.books('id in (1,2)').chapters.map(&:name).uniq  #=> ['The first chapter']

  # Scheme#all is lazy
  pp Author.all('name like ?', 'Dale%').map(&:name)
  pp Author.all('name like ?', 'Dale%').books.map(&:name) #=> single join query.
```

## N:M relationships

```ruby
  require 'swift'
  require 'swift/migrations'
  require 'swift-more'

  class Store < Swift::Record
    store      :stores
    attribute  :id,      Integer, serial: true, key: true
    attribute  :name,    String

    has_many :books, through: :stocks
  end

  class Stock < Swift::Record
    store      :stocks
    attribute  :id,       Integer, serial: true, key: true
    attribute  :store_id, Integer
    attribute  :book_id,  Integer

    belongs_to :store
    belongs_to :book
  end

  class Book < Swift::Record
    store      :books
    attribute  :id,   Integer, serial: true, key: true
    attribute  :name, String

    has_many   :stores, through: :stocks
  end

  Swift.setup :default, Swift::DB::Sqlite3, db: ':memory:'
  Swift.migrate!

  book = Book.create(name: 'test book')
  book.stores << Store.new(name: 'store 1')
  book.save
  p book.stores.reload.first.name #=> 'store 1'

  book = Book.create(name: 'another test book', stores: book.stores.all)
  p book.stores.reload.first.name #=> 'store 1'

  book = Book.create(name: 'third book', stores: Store.new(name: 'store 2'))
  p book.stores.reload.first.name #=> 'store 2'
```

## Benchmarks

* in-memory sqlite3 database
* 500 rows mapped to 5 rows each via 1:N association

```
$ cd benchmarks
$ ./simple.rb

-- driver: sqlite3 rows: 500 runs: 5 --

benchmark           sys         user        total       real        rss
ar #create       0.050000    1.400000    1.450000    1.463438    86.19m
ar #select       0.000000    0.370000    0.370000    0.373881    18.87m
ar #update       0.030000    0.860000    0.890000    0.894940    65.83m

dm #create       0.060000    1.700000    1.760000    1.766743    138.14m
dm #select       0.000000    0.310000    0.310000    0.313023    18.48m
dm #update       0.020000    0.760000    0.780000    0.775961    87.48m

sequel #create   0.050000    1.410000    1.460000    1.462936    89.01m
sequel #select   0.000000    0.040000    0.040000    0.037952    1.93m
sequel #update   0.020000    0.200000    0.220000    0.216689    13.54m

swift-m #create  0.000000    0.130000    0.130000    0.133083    10.28m
swift-m #select  0.000000    0.020000    0.020000    0.023825    3.89m
swift-m #update  0.010000    0.060000    0.070000    0.072410    6.76m
```

## Contributing

* Go nuts - there is no style guide, just a spiffy example and a patch will do.
* Bonus points for pull requests!

## LICENSE
[Creative Commons Attribution - CC BY](http://creativecommons.org/licenses/by/3.0)

## Disclaimer
Free with no guarantees - i.e. use it as you please but don't blame me if something bad happens.
