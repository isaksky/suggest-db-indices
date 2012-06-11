# -*- encoding: utf-8 -*-
require File.join File.dirname(__FILE__), 'lib/suggest_db_indices/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Isak Sky"]
  gem.email         = ["isak.sky@gmail.com"]
  gem.description   = %q{Gem that }
  gem.summary       = %q{hi}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "suggest-db-indices"
  gem.require_paths = ["lib"]
  gem.version       = SuggestDbIndices::VERSION

  gem.add_dependency('rails', '>= 3.0.0')
end
