# Suggest-Db-Indices

A gem for your rails project that suggests indices for you to add in your database. It looks for unindexed foreign keys, and what columns actually get queried.

## Installation

Add this line to your application's Gemfile:

    gem 'suggest-db-indices'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install suggest-db-indices

## Usage

1. rails console
2. 

```ruby 
require 'suggest_db_indices' 
```
3. Either index all unindexed foreign key columns:

```ruby
    SuggestDbIndices.go! 
```

or... index all foreign key columns that actually get queried (based on reading log files) 

```ruby
    SuggestDbIndices.go! :mode => :conservative 
```    
## Changes
0.0.3 (July 4, 2012) - Added justification for each index added, made log file handling more robust