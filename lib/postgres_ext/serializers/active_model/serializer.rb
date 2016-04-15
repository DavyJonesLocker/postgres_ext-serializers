module PostgresExt::Serializers::ActiveModel
  module Serializer
    def self.prepended(base)
      class << base
        prepend ClassMethods
      end
    end

    module ClassMethods
      # Wrap ActiveModel::Serializer.build_json
      # to send single records through ArraySerializer
      # enabling database serialization.
      def build_json(controller, resource, options)
        serializer_instance = super
        return serializer_instance unless serializer_instance

        default_options = controller.send(:default_serializer_options) || {}
        options = default_options.merge(options || {})

        if ActiveRecord::Base === resource && options[:root] != false && serializer_instance.root_name != false
          options[:root] ||= serializer_instance.root_name
          options[:each_serializer] = serializer_instance.class
          options[:single_record] = options.fetch(:single_record, true)
          options.delete(:serializer) # Reset to default ArraySerializer.

          # Wrap Record in a Relation.
          klass = resource.class
          primary_key = klass.primary_key
          resource = klass.where(primary_key => resource.send(primary_key)).limit(1)

          super(controller, resource, options)
        else
          serializer_instance
        end
      end
    end
  end
end
