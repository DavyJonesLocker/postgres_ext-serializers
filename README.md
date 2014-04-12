# PostgresExt-Serializers


[![Build
Status](https://secure.travis-ci.org/dockyard/postgres_ext-serializers.png?branch=master)](http://travis-ci.org/dockyard/postgres_ext-serializers)
[![Code
Climate](https://codeclimate.com/github/dockyard/postgres_ext-serializers.png)](https://codeclimate.com/github/dockyard/postgres_ext-serializers)
[![Gem
Version](https://badge.fury.io/rb/postgres_ext-serializers.png)](http://badge.fury.io/rb/postgres_ext-serializers)

## Looking for help? ##

If it is a bug [please open an issue on
Github](https://github.com/dockyard/postgres_ext-serializers/issues). If you need
help using the gem please ask the question on
[Stack Overflow](http://stackoverflow.com). Be sure to tag the
question with `DockYard` so we can find it.

## Installation

Add this line to your application's Gemfile:

    gem 'postgres_ext-serializers'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install postgres_ext-serializers

## Usage

Just `require 'postgres_ext/serializers'` and use
ActiveModel::Serializers as you normally would!
Postgres\_ext-serializers will take over anytime you try to serialize an
ActiveRecord::Relation.

### Methods in Serializers and Models

If you are using methods to compute properties for your JSON responses
in your models or serializers, postgres\_ext-serializers will try to
discover a SQL version of this call by looking for a class method with
the same name and the prefex `__sql`. Here's an example:

```ruby
class MySerializer < ActiveModel::Serializer
  def full_name
    "#{object.first_name} #{object.last_name}"
  end

  def self.full_name__sql(scope)
    'first_name || ' ' || last_name'
  end
end
```

The scope is passed to methods in a serializer, while there are no
arguments passed to `__sql` methods in a model. You will not have access
to the `current_user` alias of `scope`, but the scope passed in will be
the same object. Right now, this string is used as a SQL literal, so be
sure to *not* use untrusted values in the return value. This feature may
change before the 1.0 release, if a cleaner implementation is found.

## Developing

To work on postgres\_ext locally, follow these steps:

 1. Run `bundle install`, this will install all the development
    dependencies
 2. Run `rake setup`, this will set up the `.env` file necessary to run
    the tests and set up the database
 3. Run `rake db:create`, this will create the test database
 4. Run `rake db:migrate`, this will set up the database tables required
    by the test

## Authors

Dan McClain [twitter](http://twitter.com/_danmcclain)
[github](http://github.com/danmcclain)

