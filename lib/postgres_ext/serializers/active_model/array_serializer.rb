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

    private

    def _postgres_serializable_array
      visitor = object.klass.connection.visitor
      attributes = object.klass.active_model_serializer._attributes
      object_query = object.dup
      object_query_arel = object_query.arel_table
      attributes.each do |name, key|
        if name.to_s == key.to_s
          object_query = object_query.select(object_query_arel[name])
        end
      end

      object_cte_name, object_as_json_arel = _relation_to_json_array_arel object_query

      jsons_table = Arel::Table.new 'jsons'
      jsons_row_to_json = Arel::Nodes::NamedFunction.new 'row_to_json', [Arel.sql(jsons_table.name)]
      jsons_select_manager = jsons_table.project jsons_row_to_json
      jsons_as = Arel::Nodes::As.new Arel.sql(jsons_table.name), Arel.sql(visitor.accept object_as_json_arel)
      json_as = Arel::Nodes::As.new Arel.sql(object_cte_name), Arel.sql("(#{object_query.to_sql})")
      jsons_select_manager.with([json_as, jsons_as])

      object.klass.connection.select_value visitor.accept jsons_select_manager
    end

    def _relation_to_json_array_arel(relation)
      json_table = Arel::Table.new "#{relation.table_name}_json"
      json_select_manager = json_table.project _results_as_json_array(json_table.name, relation.table_name)

      [json_table.name, json_select_manager]
    end

    def _row_to_json(table_name, aliaz = nil)
      _postgres_function_node 'row_to_json', [Arel.sql(table_name)], aliaz
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

