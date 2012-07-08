# -*- encoding: utf-8 -*-
require File.join File.dirname(__FILE__), 'lib/suggest_db_indices/version'

Gem::Specification.new do |gem|
  gem.authors = ["Isak Sky"]
  gem.email = ["isak.sky@gmail.com"]
  gem.description = "A gem for rails projects that suggests indices to add to the database."
  gem.summary = "A gem for rails projects that suggests indices to add to the database."
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
