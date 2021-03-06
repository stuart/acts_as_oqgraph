# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{acts_as_oqgraph}
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stuart Coyle"]
  s.date = %q{2011-09-13}
  s.description = %q{Acts As OQGraph allows ActiveRecord models to use the fast and powerful OQGraph engine for MYSQL.}
  s.email = %q{stuart.coyle@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    "Gemfile",
    "LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "acts_as_oqgraph.gemspec",
    "lib/acts_as_oqgraph.rb",
    "lib/graph_edge.rb",
    "test/helper.rb",
    "test/models/custom_test_model.rb",
    "test/models/test_model.rb",
    "test/test_acts_as_oqgraph.rb"
  ]
  s.homepage = %q{http://github.com/stuart/acts_as_oqgraph}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{Use the Open Query Graph engine with Active Record}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mysql2>, [">= 0"])
      s.add_runtime_dependency(%q<activerecord>, [">= 0"])
      s.add_runtime_dependency(%q<jeweler>, [">= 0"])
    else
      s.add_dependency(%q<mysql2>, [">= 0"])
      s.add_dependency(%q<activerecord>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
    end
  else
    s.add_dependency(%q<mysql2>, [">= 0"])
    s.add_dependency(%q<activerecord>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
  end
end

