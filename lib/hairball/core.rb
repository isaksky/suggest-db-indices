module Hairball
  class << self
    def unindexed_foreign_key_columns_by_table
      non_pk_columns_by_table = {}
      indexes_by_table = {}

      connection.tables.each do |table_name|
        puts table_name
        non_pk_columns_by_table[table_name] = non_pk_column_names(table_name)
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

    def non_pk_column_names table_name
      connection.columns(table_name).reject do |column|
        column.name == primary_key_name(connection, table_name)
      end.map(&:name)
    end

    # Stole this from activerecord schema dumper code
    def primary_key_name connection, table_name
      if connection.respond_to?(:pk_and_sequence_for)
        connection.pk_and_sequence_for(table_name).first
      elsif connection.respond_to?(:primary_key)
        connection.primary_key(table_name)
      end
    end

    def foreign_key? column_name
      column_name.end_with? "_id"
    end

    NUM_LINES_TO_READ = 100000

    def connection
      ActiveRecord::Base.connection
    end

    def non_pk_columns_by_table
      connection.tables.reduce({}) do |memo, table_name|
        memo.merge! table_name => non_pk_column_names(table_name)
      end
    end

    def prepare_log_file log_dir
      puts "Preparing log files..."
      tmpfile = Tempfile.new('tmplog')
      log_file_names = Dir.glob File.join log_dir, '*.log'
      puts "Found log files: #{log_file_names.inspect}"

      puts "Tailing each file!"
      log_file_names.each {|f| sh_dbg "tail -n #{NUM_LINES_TO_READ} #{f} >> #{tmpfile.path}" }
      puts "Stripping color codes!"
      stripped_log_file = Tempfile.new('stripped')
      strip_color_codes! tmpfile.path, stripped_log_file.path
      stripped_log_file
    end

    def analyze_log_files log_dir, non_pk_columns_by_table = non_pk_columns_by_table
      stripped_log_file = prepare_log_file log_dir

      queried_columns_by_table = hash_of_arrays
      inferred_table_columns_by_raw_where_clause = hash_of_sets # For debugging

      while line = stripped_log_file.gets
        line = remove_limit_clause(line.strip)
        if matches = /SELECT.+FROM\s\W?(\w+)\W?\sWHERE(.+)/i.match(line)
          table = matches[1]
          raw_where_clause = matches[2]

          raw_where_clause.split.map do |s|
            s.gsub('`','')
          end.reduce([]) do |memo, identifier|
            if identifier.include?('.')
              current_table, column = identifier.split('.')
            else
              current_table, column = [table, identifier]
            end

            if non_pk_columns_by_table[current_table].include? column
              memo << [current_table, column]
            else
              memo
            end
          end.each do |(table, column)|
            queried_columns_by_table[table] << column
            inferred_table_columns_by_raw_where_clause[raw_where_clause] << [table, column]
          end
        end
      end
      [queried_columns_by_table, inferred_table_columns_by_raw_where_clause]
    end

    def hash_of_arrays
      Hash.new {|h, k| h[k] = [] }
    end

    def hash_of_sets
      Hash.new {|h, k| h[k] = Set.new }
    end

    def remove_limit_clause s
      if m = /(.+)\sLIMIT/.match(s)
        return m[1]
      else
        return s
      end
    end

    def strip_color_codes! file_name, output_path
      # From: http://serverfault.com/a/154200
      sh_dbg 'sed "s/${esc}[^m]*m//g" ' + "#{file_name} >> #{output_path}"
      raise "There was a problem stripping colors" unless $?.success?
    end

    def sh_dbg cmd
      puts "Shelling:   #{cmd}"
      `#{cmd}`
    end
  end
end
