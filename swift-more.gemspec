Gem::Specification.new do |s|
  s.name = %q{swift-more}
  s.version = '0.1.0'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Bharanee Rathna']
  s.date = %q{2010-08-23}
  s.description = %q{Swift experimental extensions.}
  s.email = ['deepfryed@gmail.com']
  s.files = [
     'lib/swift/more.rb',
     'lib/swift/inflect.rb',
     'lib/swift/associations.rb',
     'lib/swift/associations/crud.rb',
     'swift-more.gemspec'
  ]
  s.require_paths = ['lib']
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Swift experimental extensions.}
end
