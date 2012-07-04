# -*- encoding: utf-8 -*-
require File.join File.dirname(__FILE__), 'lib/suggest_db_indices/version'

Gem::Specification.new do |gem|
  gem.authors = ["Isak Sky"]
  gem.email = ["isak.sky@gmail.com"]
  gem.description = %q{A gem for your rails project that suggests indices for you to add in your database. Currently it suggests adding indices to unindexed foreign key columns.}
  gem.summary = %q{A gem for your rails project that suggests indices for you to add in your database.}
  gem.homepage = "https://github.com/isaksky/suggest-db-indices"
  gem.license = "MIT"

  gem.files = `git ls-files`.split($\)
  gem.executables = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
  gem.name = "suggest-db-indices"
  gem.require_paths = ["lib"]
  gem.version = SuggestDbIndices::VERSION

  gem.add_dependency('rails', '>= 3.0.0')
  gem.add_development_dependency('awesome_print')
  gem.add_development_dependency('pry')
end
