# Suggest-Db-Indices

A gem for your rails project that suggests indices for you to add in your database. It looks for unindexed foreign keys, and what columns actually get queried.

http://www.youtube.com/watch?v=FTt5mVdGVXQ

## Installation

Add this line to your application's Gemfile:

    gem 'suggest-db-indices'

And then execute:

    $ bundle

## Usage

    bundle exec rake suggest_db_indices

Also see: http://www.youtube.com/watch?v=FTt5mVdGVXQ

## Changes
0.1.0 (July 8, 2012) - Added the rake task.

0.0.3 (July 4, 2012) - Added justification for each index added, made log file handling more robust
