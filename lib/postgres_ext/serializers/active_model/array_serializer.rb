module PostgresExt::Serializers::ActiveModel
  module ArraySerializer
    def self.prepended(base)
      base.send :include, IncludeMethods
    end

    module IncludeMethods
      def to_json(*)
        if ActiveRecord::Relation === object
          _postgres_serializable_array
        else
          super
        end
      end
    end

    private

    def _reset_internal_state!
      @_ctes = []
      @_results_tables = {}
      @_embedded = []
      @_cte_names = []
      @_connection = object.klass.connection
      @_visitor = @_connection.visitor
    end

    def _postgres_serializable_array
      _reset_internal_state!
      _include_relation_in_root(object, serializer: @options[:each_serializer], root: @options[:root])

      jsons_select_manager = _results_table_arel(@options[:single_record] ? @options[:root] : nil)
      jsons_select_manager.with @_ctes

      @_connection.select_value _to_sql(jsons_select_manager)
    end

    def _include_relation_in_root(relation, *args)
      local_options = args.extract_options!
      foreign_key_column = args[0]
      constraining_table = args[1]

      relation_query = relation
      relation_query_arel = relation_query.arel_table

      klass = ActiveRecord::Relation === relation ? relation.klass : relation
      if local_options[:serializer].present?
        serializer_class = local_options[:serializer]
      else
        serializer_class = _serializer_class(klass)
      end

      _serializer = serializer_class.new klass.new, options
      root_key = local_options.fetch(:root, _serializer.root_name.to_s.pluralize).to_s
      @_embedded << root_key

      attributes = serializer_class._attributes.select do |key, value|
        if(_serializer.respond_to?("include_#{key}?"))
          _serializer.send("include_#{key}?")
        else
          true
        end
      end

      attributes.each do |name, key|
        if name.to_s == key.to_s
          if _serializer.respond_to? "#{name}__sql"
            relation_query = relation_query.select Arel::Nodes::As.new Arel.sql(_serializer.send("#{name}__sql")), Arel.sql(name.to_s)
          elsif serializer_class.respond_to? "#{name}__sql"
            warn "[DEPRECATION] postgres_ext-serializer - class serializer sql computed properties is deprecated. Please use instance method instead."
            relation_query = relation_query.select Arel::Nodes::As.new Arel.sql(serializer_class.send("#{name}__sql", options[:scope])), Arel.sql(name.to_s)
          elsif klass.respond_to? "#{name}__sql"
            relation_query = relation_query.select Arel::Nodes::As.new Arel.sql(klass.send("#{name}__sql")), Arel.sql(name.to_s)
          else
            relation_query = relation_query.select(relation_query_arel[name])
          end
        end
      end

      if foreign_key_column && constraining_table
        if local_options[:belongs_to]
          relation_query = relation_query.where(relation_query_arel[:id].in(constraining_table.project(constraining_table[foreign_key_column])))
        else
          relation_query = relation_query.where(relation_query_arel[foreign_key_column].in(constraining_table.project(constraining_table[:id])))
        end
      end

      associations = serializer_class._associations.select do |key, value|
        if(_serializer.respond_to?("include_#{key}?"))
          _serializer.send("include_#{key}?")
        else
          true
        end
      end

      association_sql_tables = []
      ids_table_name = nil
      id_query = nil
      unless associations.empty?
        ids_table_name = "#{relation.table_name}_ids"
        ids_table_arel =  Arel::Table.new ids_table_name
        id_query = relation.dup.select(relation_query_arel[:id])
        if foreign_key_column && constraining_table
          if local_options[:belongs_to]
            id_query.where!(relation_query_arel[:id].in(constraining_table.project(constraining_table[foreign_key_column])))
          else
            id_query.where!(relation_query_arel[foreign_key_column].in(constraining_table.project(constraining_table[:id])))
          end
        end
      end

      associations.each do |key, association_class|
        association = association_class.new key, _serializer, options

        association_reflection = klass.reflect_on_association(key)
        fkey = association_reflection.foreign_key
        if association.embed_ids?
          if association_reflection.macro == :has_many
            unless @_ctes.find { |as| as.left == ids_table_name }
              @_ctes << _postgres_cte_as(ids_table_name, "(#{id_query.to_sql})")
            end
            association_sql_tables << _process_has_many_relation(association.key, association.embed_key, association_reflection, relation_query, ids_table_arel)
          elsif klass.column_names.include?(fkey) && !attributes.include?(fkey.to_sym)
            relation_query = relation_query.select(relation_query_arel[fkey].as(association.key.to_s))
          end
        end
      end

      arel = relation_query.arel.dup

      if arel.orders.empty? && associations.present? && (arel.limit || arel.offset && arel.offset > 0)
        # Join ids CTE to filter CTE to ensure same records are selected in absence of ORDER BY.
        # This is needed because without an explicit ORDER BY record order in postgres is non-deterministic.
        # The record order only matters, if there is a LIMIT or OFFSET present.
        arel.join(ids_table_arel, Arel::Nodes::InnerJoin).on(relation_query_arel[:id].eq(ids_table_arel[:id]))
        arel.limit = nil
        arel.offset = nil
      end

      association_sql_tables.each do |assoc_hash|
        assoc_table = Arel::Table.new assoc_hash[:table]
        arel.join(assoc_table, Arel::Nodes::OuterJoin).on(relation_query_arel[:id].eq(assoc_table[assoc_hash[:foreign_key]]))
        arel.project _coalesce_arrays(assoc_table[assoc_hash[:ids_column]], assoc_hash[:ids_column])
      end

      bind_values = []
      bind_values += relation.arel.bind_values if relation.respond_to?(:arel) && relation.arel.respond_to?(:bind_values)
      bind_values += relation.bind_values if relation.respond_to?(:bind_values)
      relation_table = _arel_to_cte(arel, root_key, bind_values)

      associations.each do |key, association_class|
        association = association_class.new key, _serializer, options
        association_reflection = klass.reflect_on_association(key)

        if association.embed_in_root? && !@_embedded.member?(key.to_s)
          belongs_to = (association_reflection.macro == :belongs_to)
          constraining_table_param = association_reflection.macro == :has_many ? ids_table_arel : relation_table
          association_query = _reflection_scope(association_reflection)

          _include_relation_in_root(association_query, association_reflection.foreign_key,
            constraining_table_param, serializer: association.target_serializer, belongs_to: belongs_to, root: association_class.options[:root])
        end
      end
    end

    def _process_has_many_relation(key, embed_key, association_reflection, relation_query, ids_table_arel)
      association_class = association_reflection.klass
      association_arel_table = association_class.arel_table
      association_query = _reflection_scope(association_reflection)
      association_query = association_query.group association_arel_table[association_reflection.foreign_key]
      association_query = association_query.select(association_arel_table[association_reflection.foreign_key])
      id_column_name = key.to_s
      cte_name = "#{id_column_name}_by_#{relation_query.table_name}"
      association_query = association_query.reorder(nil).select(_array_agg(association_arel_table[embed_key.to_sym], association_query.arel.orders, id_column_name))
      association_query = association_query.having(association_arel_table[association_reflection.foreign_key].in(ids_table_arel.project(ids_table_arel[:id])))
      @_ctes << _postgres_cte_as(cte_name, "(#{association_query.to_sql})")
      { table: cte_name, ids_column: id_column_name, foreign_key: association_reflection.foreign_key }
    end

    def _reflection_scope(reflection)
      relation = reflection.klass.all
      if reflection.scope
        relation.instance_exec(&reflection.scope)
      else
        relation
      end
    end

    def _to_sql(arel, bind_values = nil)
      if @_visitor.method(:accept).arity == 2
        collector = Arel::Collectors::SQLString.new
        collector = @_visitor.accept arel, collector
        res = collector.value
        unless bind_values.nil?
          bind_values.each_with_index do |bv, i|
            value = @_connection.quote(bv[1])
            res = res.gsub(/\$#{i+1}(\b|\Z)/, value)
          end
        end
        res
      else
        @_visitor.accept arel
      end
    end

    def _serializer_class(klass)
      klass.active_model_serializer
    end

    def _coalesce_arrays(column, aliaz = nil)
      _postgres_function_node 'COALESCE', [column, Arel.sql("'{}'")], aliaz
    end

    def _results_table_arel(singular_key = nil)
      tables = []
      @_results_tables.each do |key, array|
        json_table = array
          .map {|t| t.project(Arel.star) }
          .inject {|t1, t2| Arel::Nodes::Union.new(t1, t2) }
        json_table = Arel::Nodes::As.new json_table, Arel.sql("tbl")
        json_table = Arel::Table.new(:t).from(json_table)

        json_select_manager = if singular_key.to_s == key.to_s
          # Single resource is embedded as object instead of array.
          json_table.project("COALESCE(row_to_json(tbl), '{}') as #{key}, 1 as match")
        elsif @_connection.send('postgresql_version') >= 90300
          json_table.project("COALESCE(json_agg(tbl), '[]') as #{key}, 1 as match")
        else
          json_table.project("COALESCE(array_to_json(array_agg(row_to_json(tbl))), '[]') as #{key}, 1 as match")
        end

        @_ctes << _postgres_cte_as("#{key}_as_json_array", _to_sql(json_select_manager))
        tables << { table: "#{key}_as_json_array", column: key }
      end

      first = tables.shift
      first_table = Arel::Table.new first[:table]
      jsons_select = first_table.project first_table[first[:column]]

      tables.each do |table_info|
        table = Arel::Table.new table_info[:table]
        jsons_select = jsons_select.project table[table_info[:column]]
        jsons_select.join(table).on(first_table[:match].eq(table[:match]))
      end

      @_ctes << _postgres_cte_as('jsons', _to_sql(jsons_select))

      jsons_table = Arel::Table.new 'jsons'
      jsons_table.project("row_to_json(#{jsons_table.name})")
    end

    def _arel_to_cte(arel, name, bind_values)
      cte_name = _make_cte_name_unique("#{name}_attributes_filter")
      cte_table = Arel::Table.new cte_name
      @_ctes << _postgres_cte_as(cte_table.name, _to_sql(arel, bind_values))
      @_results_tables[name] = [] unless @_results_tables.has_key?(name)
      @_results_tables[name] << cte_table
      cte_table
    end

    def _make_cte_name_unique(orig_name)
      cte_name = orig_name
      idx = 2
      while @_cte_names.include?(cte_name) do
        cte_name = "#{orig_name}#{idx}"
        idx+=1
      end
      @_cte_names << cte_name
      cte_name
    end

    def _postgres_cte_as(name, sql_string)
      Arel::Nodes::As.new Arel.sql(name), Arel.sql(sql_string)
    end

    def _array_agg(column, orders, aliaz = nil)
      if orders.present?
        # Hack to build ORDER BY inside aggregate function
        stmt = Arel::Nodes::SelectStatement.new
        stmt.cores.last.projections << column
        stmt.orders = orders

        sql = stmt.to_sql.sub(/^SELECT /, '')
        column = Arel::Nodes::SqlLiteral.new(sql)
      end

      _postgres_function_node 'array_agg', [column], aliaz
    end

    def _postgres_function_node(name, values, aliaz = nil)
      Arel::Nodes::NamedFunction.new(name, values, aliaz)
    end
  end
end
