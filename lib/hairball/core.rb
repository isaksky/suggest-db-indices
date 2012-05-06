module Hairball


  class << self
    def help_me!
      connection = ActiveRecord::Base.connection
      non_pk_columns_by_table = {}
      indexes_by_table = {}

      connection.tables.each do |table_name|
        puts table_name
        non_pk_columns_by_table[table_name] = non_pk_column_names(connection, table_name)
        puts non_pk_columns_by_table.inspect
        # Note: can index on multiple columns, which complicates things.  Assuming user has done
        # this correctly for now...
        indexes_by_table[table_name] = connection.indexes(table_name).map {|index| index.columns}.flatten
      end

      columns_need_indexes_by_table = {}

      non_pk_columns_by_table.each do |table_name, column_names|
        columns_need_indexes_by_table[table_name] = column_names.select do |column_name|
          foreign_key?(column_name) && !column_name.in?(indexes_by_table[table_name])
        end
      end
      columns_need_indexes_by_table
    end

    def non_pk_column_names connection, table_name
      columns = connection.columns(table_name).reject {|c| c.name == primary_key_name(connection, table_name) }
      columns.map(&:name)
    end

    def primary_key_name connection, table_name
      if connection.respond_to?(:pk_and_sequence_for)
        pk, _ = connection.pk_and_sequence_for(table_name)
      elsif connection.respond_to?(:primary_key)
        pk = connection.primary_key(table_name)
      end
      pk
    end

    def foreign_key? column_name
      column_name.end_with? "_id"
    end
  end
end
