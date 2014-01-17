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
      _object_query_arel

      jsons_select_manager = _results_table_arel
      jsons_select_manager.with @_ctes

      object.klass.connection.select_value _visitor.accept(jsons_select_manager)
    end

    def _object_query_arel
        object_query = object.dup
        object_query_arel = object_query.arel_table

        # TODO: To be included when objects are filters
        # if object_query.where_values
          # object_ids_query = object_query.dup
          # object_ids_query.select!(object_query_arel[:id])
        # end
        _serializer = _serializer_class.new object.klass.new, options

        attributes = _serializer_class._attributes
        attributes.each do |name, key|
          if name.to_s == key.to_s
            object_query = object_query.select(object_query_arel[name])
          end
        end

        associations = _serializer_class._associations
        association_sql_tables = []

        associations.each do |key, association_class|
          association = association_class.new key, _serializer, options

          association_reflection = object.klass.reflect_on_association(key)
          if association.embed_ids?
            association_class = association_reflection.klass
            association_arel_table = association_class.arel_table
            association_query = association_class.group association_arel_table[association_reflection.foreign_key]
            association_query = association_query.select(association_arel_table[association_reflection.foreign_key])
            id_column_name = "#{key.to_s.singularize}_ids"
            cte_name = "#{id_column_name}_by_#{object_query.table_name}"
            association_query = association_query.select(_array_agg(association_arel_table[:id], id_column_name))
            @_ctes << _postgres_cte_as(cte_name, "(#{association_query.to_sql})")
            association_sql_tables << { table: cte_name, ids_column: id_column_name, foreign_key: association_reflection.foreign_key }
          end
        end
        arel = object_query.arel.dup

        association_sql_tables.each do |assoc_hash|
          assoc_table = Arel::Table.new assoc_hash[:table]
          arel.join(assoc_table, Arel::Nodes::OuterJoin).on(object_query_arel[:id].eq(assoc_table[assoc_hash[:foreign_key]]))
          arel.project _coalesce_arrays(assoc_table[assoc_hash[:ids_column]], assoc_hash[:ids_column])
        end

        json_array_arel = _arel_to_json_array_arel(arel, object_query.table_name)
      @_ctes << _postgres_cte_as('jsons', _visitor.accept(json_array_arel))
    end

    def _visitor
      @_visitior ||= object.klass.connection.visitor
    end

    def _serializer_class
      @_serializer_class = object.klass.active_model_serializer
    end

    def _coalesce_arrays(column, aliaz = nil)
      _postgres_function_node 'coalesce', [column, Arel.sql("'{}'::int[]")], aliaz
    end

    def _results_table_arel
      jsons_table = Arel::Table.new 'jsons'
      jsons_row_to_json = _row_to_json jsons_table.name
      jsons_table.project jsons_row_to_json
    end

    def _arel_to_json_array_arel(arel, name)
      json_table = Arel::Table.new "#{name}_json"
      json_select_manager = json_table.project _results_as_json_array(json_table.name, name)

      @_ctes << _postgres_cte_as(json_table.name, _visitor.accept(arel))
      json_select_manager
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

    def _array_agg(column, aliaz = nil)
       _postgres_function_node 'array_agg', [column], aliaz
    end

    def _array_agg_as_json(column, aliaz = nil)
      array_agg = _array_agg [column]
      _postgres_function_node 'array_to_json', [array_agg], aliaz
    end

    def _postgres_function_node(name, values, aliaz = nil)
      Arel::Nodes::NamedFunction.new(name, values, aliaz)
    end
  end
end

