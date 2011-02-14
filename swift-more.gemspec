Gem::Specification.new do |s|
  s.name                      = 'swift-more'
  s.version                   = '0.3.6'
  s.rubygems_version          = '1.3.7'
  s.authors                   = ['Bharanee Rathna']
  s.email                     = ['deepfryed@gmail.com']
  s.summary                   = 'Swift ORM extensions.'
  s.description               = 'Swift ORM extensions - light weight associations.'
  s.homepage                  = 'http://github.com/deepfryed/swift-more'
  s.date                      = '2011-01-09'
  s.require_paths             = %w(lib)
  s.files                     = Dir.glob(File.dirname(__FILE__) + '/lib/**/*.rb')
  s.required_rubygems_version = Gem::Requirement.new('>= 1.3.6')

  s.add_dependency             'swift',    ['~> 0.9.0']
  s.add_development_dependency 'swift',    ['~> 0.9.0']
  s.add_development_dependency 'minitest', ['~> 2.0.1']
end
