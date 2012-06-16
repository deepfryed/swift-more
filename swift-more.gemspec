# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "swift-more"
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Bharanee Rathna"]
  s.date = "2012-06-17"
  s.description = "Swift ORM extensions - light weight associations."
  s.email = ["deepfryed@gmail.com"]
  s.files = ["test/test_has_one.rb", "test/test_belongs_to.rb", "test/test_lazy_all.rb", "test/test_has_many.rb", "test/minitest/pretty.rb", "test/helper.rb", "test/test_has_many_through.rb", "test/test_dirty_attribute.rb", "lib/swift/associations/migrations.rb", "lib/swift/associations/sql.rb", "lib/swift/inflect.rb", "lib/swift/persistence.rb", "lib/swift/object.rb", "lib/swift/type-resolution.rb", "lib/swift/associations.rb", "lib/swift-more.rb", "README.md"]
  s.homepage = "http://github.com/deepfryed/swift-more"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "Swift ORM extensions."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<swift>, [">= 0.14.0"])
      s.add_development_dependency(%q<minitest>, [">= 0"])
    else
      s.add_dependency(%q<swift>, [">= 0.14.0"])
      s.add_dependency(%q<minitest>, [">= 0"])
    end
  else
    s.add_dependency(%q<swift>, [">= 0.14.0"])
    s.add_dependency(%q<minitest>, [">= 0"])
  end
end
