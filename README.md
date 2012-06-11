# Suggest-Db-Indices

A gem for your rails project that suggests indices for you to add in your database. Currently it suggests adding indexes to unindexed foreign keys.

## Installation

Add this line to your application's Gemfile:

    gem 'suggest-db-indices'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install suggest-db-indices

## Usage

1. rails console
2. require 'suggest_db_indices'
3. SuggestDbIndices.go!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Possible future features
1. I have built some things for analyzing the rails log files and looking at columns used in the queries that get run. I need to come up with a good way to use these results.
2. Next to each add index statement, there should be a justification.
