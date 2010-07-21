# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{acts_as_oqgraph}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stuart Coyle"]
  s.date = %q{2010-07-21}
  s.description = %q{Acts As OQGraph allows ActiveRecord models to use the fast ans powerful OQGraph engine for MYSQL.}
  s.email = %q{stuart.coyle@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
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
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Use the Open Query Graph engine with Active Record}
  s.test_files = [
    "test/helper.rb",
     "test/models/custom_test_model.rb",
     "test/models/test_model.rb",
     "test/test_acts_as_oqgraph.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

