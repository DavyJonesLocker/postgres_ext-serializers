require 'active_record'
require 'minitest/autorun'
require 'bourne'
require 'database_cleaner'
require 'postgres_ext/serializers'
unless ENV['CI'] || RUBY_PLATFORM =~ /java/
  require 'byebug'
end

require 'dotenv'
Dotenv.load

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

class TestController < ActionController::Base
  def url_options
    {}
  end
end

class Person < ActiveRecord::Base
  def self.full_name__sql
    "first_name || ' ' || last_name"
  end
end

class PeopleController < TestController; end

class PersonSerializer < ActiveModel::Serializer
  attributes :id, :full_name, :attendance_name

  def self.attendance_name__sql(scope)
    if scope &&  scope[:admin]
      "'ADMIN ' || last_name || ', ' || first_name"
    else
      "last_name || ', ' || first_name"
    end
  end
end

class Note < ActiveRecord::Base
  has_many :tags
end

class NotesController < TestController; end

class NoteSerializer < ActiveModel::Serializer
  attributes :id, :content, :name
  has_many   :tags
  embed      :ids, include: true
end

class Tag < ActiveRecord::Base
  belongs_to :note
end



class TagSerializer < ActiveModel::Serializer
  attributes :id, :name
  embed :ids
  has_one :note
end

DatabaseCleaner.strategy = :deletion

class Minitest::Spec
  class << self
    alias :context :describe
  end

  before do
    DatabaseCleaner.start
  end

  after do
    DatabaseCleaner.clean
  end
end
