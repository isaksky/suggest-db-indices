# -*- encoding: utf-8 -*-
require File.join File.dirname(__FILE__), 'lib/suggest_db_indices/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Isak Sky"]
  gem.email         = ["isak.sky@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "suggest-db-indices"
  gem.require_paths = ["lib"]
  gem.version       = Suggest_Db_Indices::VERSION

  gem.add_dependency('rails', '>= 3.0.0')
end
