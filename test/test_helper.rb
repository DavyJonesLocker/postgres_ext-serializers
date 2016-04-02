require 'active_record'
require 'minitest/autorun'
require 'bourne'
require 'database_cleaner'
if ENV['TEST_UNPATCHED_AMS']
  require 'active_model_serializers'
else
  require 'postgres_ext/serializers'
end
unless ENV['CI'] || RUBY_PLATFORM =~ /java/
  begin
    require 'byebug'
  rescue LoadError
  end
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

  def attendance_name__sql
    if current_user && current_user[:admin]
      "'ADMIN ' || last_name || ', ' || first_name"
    else
      "last_name || ', ' || first_name"
    end
  end
end

class Note < ActiveRecord::Base
  has_many :tags
  has_many :sorted_tags
  has_many :custom_sorted_tags, lambda { order(:name) }, class_name: 'Tag'
  has_many :popular_tags, lambda { where(popular: true) }, class_name: 'Tag'
end

class NotesController < TestController; end

class NoteSerializer < ActiveModel::Serializer
  attributes :id, :content, :name
  has_many   :tags
  embed      :ids, include: true
end

class ShortTagSerializer < ActiveModel::Serializer
  attributes :id, :name
end

class SortedTagSerializer < ActiveModel::Serializer
  attributes :id, :name
end

class CustomKeyTagSerializer < ActiveModel::Serializer
  attributes :id, :name
  embed :ids
  has_one :note, key: :tagged_note_id
end

class OtherNoteSerializer < ActiveModel::Serializer
  attributes :id, :name
  has_many   :tags, serializer: ShortTagSerializer, embed: :ids, include: true
end

class CustomKeysNoteSerializer < ActiveModel::Serializer
  attributes :id, :name
  has_many   :tags, serializer: CustomKeyTagSerializer, embed: :ids, include: true, key: :tag_names, embed_key: :name
end

class SortedTagsNoteSerializer < ActiveModel::Serializer
  attributes :id
  has_many   :sorted_tags
  embed      :ids, include: true
end

class CustomSortedTagsNoteSerializer < ActiveModel::Serializer
  attributes :id
  has_many   :custom_sorted_tags, serializer: ShortTagSerializer
  embed      :ids, include: true
end

class Tag < ActiveRecord::Base
  belongs_to :note
end

class SortedTag < Tag
  belongs_to :note
  default_scope { order(:name) }
end

class TagsController < TestController; end

class TagSerializer < ActiveModel::Serializer
  attributes :id, :name
  embed :ids
  has_one :note
end

class TagWithNoteSerializer < ActiveModel::Serializer
  attributes :id, :name
  embed :ids, include: true
  has_one :note
end

class User < ActiveRecord::Base
  has_many :offers, foreign_key: :created_by_id, inverse_of: :created_by
  has_many :reviewed_offers, foreign_key: :reviewed_by_id, inverse_of: :reviewed_by, class_name: 'Offer'
  has_one :address
end

class Address < ActiveRecord::Base
  belongs_to :user
end

class Offer < ActiveRecord::Base
  belongs_to :created_by, class_name: 'User', inverse_of: :offers
  belongs_to :reviewed_by, class_name: 'User', inverse_of: :reviewed_offers
end

class UsersController < TestController; end
class AddressController < TestController; end

class OfferSerializer < ActiveModel::Serializer
  attributes :id
end

class AddressSerializer < ActiveModel::Serializer
  attributes :id, :district_name
  embed :ids, include: true
end

class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :mobile
  embed :ids, include: true
  has_many :offers, serializer: OfferSerializer
  has_many :reviewed_offers, serializer: OfferSerializer
  has_one :address, serializer: AddressSerializer

  def include_mobile?
    current_user && current_user[:permission_id]
  end
  alias_method :include_address?, :include_mobile?
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
