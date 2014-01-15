module PostgresExt::Serializers::ActiveModel
  module ArraySerializer
    def self.prepended(base)
      base.send :include, IncludeMethods
    end
    # Look at ActiveModel.include! logic line 415
    # object.klass.active_model_serializer._associations
    # association.embed_in_root? && association.embeddable? ( 422)
    # association.embed_objects? 

    module IncludeMethods
      def to_json(*args)
        if ActiveRecord::Relation === object
          _postgres_serializable_array
        else
          super
        end
      end
    end

    def initialize(*args)
      super
      @_ctes = []
    end

    private

    def _postgres_serializable_array
      object_as_json_arel = _relation_to_json_array_arel _object_query

      jsons_select_manager = _results_table_arel
      @_ctes << _postgres_cte_as('jsons', _visitor.accept(object_as_json_arel))
      jsons_select_manager.with @_ctes

      object.klass.connection.select_value _visitor.accept(jsons_select_manager)
    end

    def _object_query
      @_object_query ||= -> do
        attributes = object.klass.active_model_serializer._attributes
        object_query = object.dup
        object_query_arel = object_query.arel_table
        attributes.each do |name, key|
          if name.to_s == key.to_s
            object_query = object_query.select(object_query_arel[name])
          end
        end
        object_query
      end.call()
    end

    def _visitor
      @_visitior ||= object.klass.connection.visitor
    end

    def _results_table_arel
      jsons_table = Arel::Table.new 'jsons'
      jsons_row_to_json = _row_to_json jsons_table.name
      jsons_table.project jsons_row_to_json
    end

    def _relation_to_json_array_arel(relation)
      json_table = Arel::Table.new "#{relation.table_name}_json"
      json_select_manager = json_table.project _results_as_json_array(json_table.name, relation.table_name)

      @_ctes << _postgres_cte_as(json_table.name, "(#{relation.to_sql})")

      json_select_manager
    end

    def _row_to_json(table_name, aliaz = nil)
      _postgres_function_node 'row_to_json', [Arel.sql(table_name)], aliaz
    end

    def _postgres_cte_as(name, sql_string)
      Arel::Nodes::As.new Arel.sql(name), Arel.sql(sql_string)
    end

    def _results_as_json_array(table_name, aliaz = nil)
      row_as_json = _row_to_json table_name
      array_of_json = _postgres_function_node 'array_agg', [row_as_json]
      _postgres_function_node 'array_to_json', [array_of_json], aliaz
    end

    def _postgres_function_node(name, values, aliaz = nil)
      Arel::Nodes::NamedFunction.new(name, values, aliaz)
    end
  end
end

