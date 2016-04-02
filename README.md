# PostgresExt-Serializers


[![Build
Status](https://secure.travis-ci.org/DockYard/postgres_ext-serializers.png?branch=master)](https://travis-ci.org/DockYard/postgres_ext-serializers)
[![Code
Climate](https://codeclimate.com/github/dockyard/postgres_ext-serializers.png)](https://codeclimate.com/github/dockyard/postgres_ext-serializers)
[![Gem
Version](https://badge.fury.io/rb/postgres_ext-serializers.png)](https://badge.fury.io/rb/postgres_ext-serializers)

# Note: Current release is AMS 0.8.x compatible
There will be updates coming to make it 0.9.x compatible

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
the same name and the suffix `__sql`. Here's an example:

```ruby
class MyModel < ActiveRecord::Base
  def full_name
    "#{object.first_name} #{object.last_name}"
  end

  def self.full_name__sql
    "first_name || ' ' || last_name"
  end
end

class MySerializer < ActiveModel::Serializer
  def full_name
    "#{object.first_name} #{object.last_name}"
  end

  def full_name__sql
    "first_name || ' ' || last_name"
  end
end
```

There is no instance of MyModel created so sql computed properties needs to be
a class method. Right now, this string is used as a SQL literal, so be sure to
*not* use untrusted values in the return value.

### Note: Postgres date, timestamp or timestamptz format
Postgres 9.2 and 9.3 by default renders dates according to the current DateStyle
Postgres setting, but many JSON processors require dates to be in ISO 8601
format e.g. Firefox or Internet Explorer will parse string as invalid date with
default DateStyle setting. Postgres 9.4 onwards now uses ISO 8601 for JSON
serialization instead.

## Developing

To work on postgres\_ext-serializers locally, follow these steps:

 1. Run `bundle install`, this will install (almost) all the development
    dependencies
 2. Run `gem install byebug` (not a declared dependency to not break CI)
 3. Run `bundle exec rake setup`, this will set up the `.env` file necessary to run
    the tests and set up the database
 4. Run `bundle exec rake db:create`, this will create the test database
 5. Run `bundle exec rake db:migrate`, this will set up the database tables required
    by the test
 6. Run `BUNDLE_GEMFILE='gemfiles/Gemfile.activerecord-4.2.x' bundle install --quiet` to create the Gemfile.lock.
 7. Run `bundle exec rake test:all` to run tests against all supported versions of Active Record (currently 4.0.x, 4.1.x, 4.2.x)

## Authors

Dan McClain [twitter](http://twitter.com/_danmcclain)
[github](http://github.com/danmcclain)

[We are very thankful for the many contributors](https://github.com/dockyard/postgres_ext-serializers/graphs/contributors)

## Versioning ##

This gem follows [Semantic Versioning](http://semver.org)

## Want to help? ##

Please do! We are always looking to improve this gem.

## Legal ##

[DockYard](http://dockyard.com), Inc &copy; 2014

[@dockyard](http://twitter.com/dockyard)

[Licensed under the MIT license](http://www.opensource.org/licenses/mit-license.php)
