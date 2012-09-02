# encoding: utf-8

$:.unshift File.dirname(__FILE__) 

require 'date'
require 'pathname'
require 'rake'
require 'rake/testtask'

$rootdir = Pathname.new(__FILE__).dirname
$gemspec = Gem::Specification.new do |s|
  s.name                      = 'swift-more'
  s.version                   = '0.5.0'
  s.authors                   = ['Bharanee Rathna']
  s.email                     = ['deepfryed@gmail.com']
  s.summary                   = 'Swift ORM extensions.'
  s.description               = 'Swift ORM extensions - light weight associations.'
  s.homepage                  = 'http://github.com/deepfryed/swift-more'
  s.date                      = Date.today
  s.require_paths             = %w(lib)
  s.files                     = Dir.glob(File.dirname(__FILE__) + '/lib/**/*.rb')
  s.files                     = Dir['{ext,test,lib}/**/*.rb'] + %w(README.md)

  s.add_dependency             'swift', '>= 0.14.0'
  s.add_development_dependency 'minitest'
end

desc 'Generate gemspec'
task :gemspec do 
  $gemspec.date = Date.today
  File.open("#{$gemspec.name}.gemspec", 'w') {|fh| fh.write($gemspec.to_ruby)}
end

Rake::TestTask.new(:test) do |test|
  test.libs   << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task default: :test
