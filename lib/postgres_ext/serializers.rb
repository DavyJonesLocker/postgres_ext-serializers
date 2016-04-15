require 'postgres_ext'
require 'postgres_ext/serializers/version'

module PostgresExt
  module Serializers
  end
end

require 'postgres_ext/serializers/active_model'
require 'active_model_serializers'

ActiveModel::ArraySerializer.send :prepend, PostgresExt::Serializers::ActiveModel::ArraySerializer
ActiveModel::Serializer.send :prepend, PostgresExt::Serializers::ActiveModel::Serializer
