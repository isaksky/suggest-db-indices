module SuggestDbIndices
  class << self
    def indexed_columns_by_table
      @indexed_columns_by_table ||= connection.tables.reduce({}) do |h, table_name|
        # Note: can index on multiple columns, which complicates things.  Assuming user has done
        # this correctly for now...
        h.merge table_name => connection.indexes(table_name).map {|index| index.columns}.flatten
      end
    end

    def non_pk_column_names table_name
      connection.columns(table_name).reject do |column|
        column.name == primary_key_name(connection, table_name)
      end.map(&:name)
    end

    def non_pk_columns_by_table
      @non_pk_columns_by_table ||= connection.tables.reduce({}) do |h, table_name|
        h.merge! table_name => non_pk_column_names(table_name)
      end
    end

    # Stole this from activerecord schema dumper code
    def primary_key_name connection, table_name
      if connection.respond_to?(:pk_and_sequence_for)
        connection.pk_and_sequence_for(table_name).first rescue nil
      elsif connection.respond_to?(:primary_key)
        connection.primary_key(table_name)
      end
    end

    def foreign_key? column_name
      column_name.end_with? "_id"
    end

    NUM_LINES_TO_READ = 1000

    def connection
      ActiveRecord::Base.connection
    end

    def unindexed_columns_by_table
      non_pk_columns_by_table.reduce({}) do |h, (table, columns)|
        h.merge table => columns - (indexed_columns_by_table[table] || [])
      end
    end

    def unindexed_foreign_key_columns_by_table
      unindexed_columns_by_table.reduce({}) do |h, (table, columns)|
        h.merge table => columns.select {|col| foreign_key?(col) }
      end
    end

    def go! config = {}
      @config = default_options.reduce(config) do |h, (k,v)|
        if h[k]
          h
        else
          h.merge! k => v
        end
      end
      generate_migration_file! format_index_migration_string unindexed_foreign_key_columns_by_table
    end

    def format_index_migration_string columns_by_table
      add_index_statements = columns_by_table.reduce('') do |s, (table, columns)|
        columns.each {|col| s += "    add_index :#{table}, :#{col}\n" }
        s
      end
      "  def change\n#{add_index_statements}\n  end\nend"
    end

    def generate_migration_file! migration_contents
      _ , migration_file_path  = Rails::Generators.invoke("active_record:migration",
                                                          ["add_indexes_via_suggest_db_indices_#{rand(36**8).to_s(36)}",
                                                           'BoiledGoose:Animal'])
      file_contents = File.read migration_file_path
      search_string = "ActiveRecord::Migration"
      stop_index = (file_contents.index(search_string)) + search_string.length
      new_file_contents = file_contents[0..stop_index] + migration_contents
      File.open(migration_file_path, 'w') {|f| f.write(new_file_contents) }
      migration_file_path
    end

    def default_options
      {:num_lines_to_scan => 10000,
        :examine_logs => false,
        :log_dir => ""}
    end

    def prepare_log_file! log_dir
      puts "Preparing log files..."
      tmpfile = Tempfile.new('tmplog')
      log_file_names = Dir.glob File.join log_dir, '*.log'
      puts "Found log files: #{log_file_names.inspect}"

      puts "Tailing each file!"
      log_file_names.each {|f| sh_dbg "tail -n #{NUM_LINES_TO_READ} #{f} >> #{tmpfile.path}" }
      puts "Stripping color codes!"
      stripped_log_file = Tempfile.new('stripped')
      # Because text search is too tricky with colors
      strip_color_codes! tmpfile.path, stripped_log_file.path
      stripped_log_file
    end

    def scan_log_files_for_queried_columns log_dir, non_pk_columns_by_table = non_pk_columns_by_table
      stripped_log_file = prepare_log_file! log_dir

      queried_columns_by_table = hash_of_arrays
      # For debugging: Record from which SQL statement we got each column
      inferred_table_columns_by_raw_where_clause = hash_of_sets

      while line = stripped_log_file.gets
        line = remove_limit_clause(line.strip)
        if matches = /SELECT.+FROM\s\W?(\w+)\W?\sWHERE(.+)/i.match(line)
          table = matches[1]

          raw_where_clause = matches[2]
#          puts "Where: #{raw_where_clause}"

          raw_where_clause.split.map do |s|
            s.gsub('`','')
          end.reduce([]) do |memo, identifier| #TODO: Stop reducing to array, reduce to counter
            if identifier.include?('.')
              current_table, column_candidate = identifier.split('.')
            else
              current_table, column_candidate = [table, identifier]
            end

            if non_pk_columns_by_table[current_table].include? column_candidate
              # We only care about the identifiers that match up to a table and column.
              # This is a ghetto way to to avoid having to parse SQL (extremely difficult)
              memo << [current_table, column_candidate]
            else
              memo
            end
          end.each do |(table, column)|
            queried_columns_by_table[table] << column
            inferred_table_columns_by_raw_where_clause[raw_where_clause] << [table, column]
          end
        end
      end
      {:queried_columns_by_table => queried_columns_by_table,
       :inferred_table_columns_by_raw_where_clause => inferred_table_columns_by_raw_where_clause}
    end

    def hash_of_arrays
      Hash.new {|h, k| h[k] = [] }
    end

    def hash_of_sets
      Hash.new {|h, k| h[k] = Set.new }
    end

    def remove_limit_clause s
      if matches = /(.+)\sLIMIT/.match(s)
        return matches[1]
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
