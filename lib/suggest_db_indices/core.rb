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

    def config
      @config ||= default_config
    end

    def go! config = {}
      @config = config.reduce(default_config) {|h, (k,v)| h.merge k => v}

      if @config[:mode] == :conservative
        scan_result = scan_log_files_for_queried_columns @config[:log_dir]
        columns_found_in_logs_by_table = scan_result[:queried_columns_by_table]
        # In conservative mode, only add indexes for columns that are both unindexed foreign
        # keys, and used in query as shown in log file.
        columns_by_table = unindexed_foreign_key_columns_by_table.reduce({}) do |h, (table, columns)|
          h.merge table => columns & columns_found_in_logs_by_table[table]
        end
      else
        columns_by_table = unindexed_foreign_key_columns_by_table
      end

      if columns_by_table.any? {|(table, columns)| columns.any? }
        generate_migration_file! format_index_migration_string columns_by_table
      else
        puts "No missing indexes found!"
      end
    end

    def format_index_migration_string columns_by_table
      add_index_statements = columns_by_table.reduce('') do |s, (table, columns)|
        columns.each {|col| s += "    add_index :#{table}, :#{col}\n" }
        s
      end
      "  def change\n#{add_index_statements}\n  end\nend"
    end

    def name_migration_file
      name = "add_indexes_via_suggest_db_indices"
      existing_migration_files = Dir.glob File.join Rails.root, 'db', 'migrate/*.rb'

      if existing_migration_files.any? {|f| f.end_with?("#{name}.rb") }
        i = 1
        i += 1 while existing_migration_files.any? {|f| f.end_with?("#{name}_#{i}.rb") }
        name += "_#{i}"
      end
      name
    end

    def generate_migration_file! migration_contents
      _ , migration_file_path  = Rails::Generators.invoke("active_record:migration",
                                                          [name_migration_file,
                                                           'BoiledGoose:Animal'])  # Bogus param, doesn't matter since contents will be replaced
      file_contents = File.read migration_file_path
      search_string = "ActiveRecord::Migration"
      stop_index = (file_contents.index(search_string)) + search_string.length
      new_file_contents = file_contents[0..stop_index] + migration_contents
      File.open(migration_file_path, 'w') {|f| f.write(new_file_contents) }
      puts "Migration result: \n #{new_file_contents}"
      migration_file_path
    end

    def default_config
      {:num_lines_to_scan => 10000,
        :examine_logs => false,
        :log_dir => File.join(Rails.root, 'log') }
    end

    def prepare_log_file! log_dir
      puts "Preparing log files..."
      tmpfile = Tempfile.new('tmplog')
      log_file_names = Dir.glob File.join log_dir, '*.log'
      puts "Found log files: #{log_file_names.inspect}"

      puts "Tailing each file!"
      log_file_names.each {|f| sh_dbg "tail -n #{config[:num_lines_to_scan]} #{f} >> #{tmpfile.path}" }
      tmpfile
    end

    def table_quote_char
      @table_quote_char ||= connection.quote_table_name("boiled_goose")[0]
    end

    def column_quote_char
      @column_quote_char ||= connection.quote_column_name("sauerkraut")[0]
    end

    # Scans log files for queried columns
    def scan_log_files log_dir = config()[:log_dir]
      stripped_log_file = prepare_log_file! log_dir

      queried_columns_by_table = hash_of_hashes
      # For debugging: Record from what table and columns we derived from each SQL statement
      inferred_table_columns_by_raw_where_clause = hash_of_sets
      non_matches = Set.new

      while line = stripped_log_file.gets
        line = remove_limit_clause(line.strip)
        if matches = /SELECT.+WHERE(.+)/i.match(line)  #Old: /.+SELECT.+FROM\s\W?(\w+)\W?\sWHERE(.+)/
          raw_where_clause = matches[1]
          #          puts "Where: #{raw_where_clause}"
          raw_where_clause.split.each do |identifier|
            next if non_matches.include? identifier
            # Go through the where clause to find columns that were queried
            if identifier.include?('.') # e.g., "post"."user_id"
              current_table, column_candidate = identifier.split('.')
              current_table.gsub! table_quote_char, ''
              column_candidate.gsub! column_quote_char, ''
              if non_pk_columns_by_table[current_table] && non_pk_columns_by_table[current_table].include?(column_candidate)
                # We only care about the identifiers that match up to a table and column.
                # This is a ghetto way to to avoid having to parse SQL (extremely difficult)
                if queried_columns_by_table.get_in([current_table,column_candidate])
                  queried_columns_by_table[current_table][column_candidate] += 1
                else
                  queried_columns_by_table[current_table] = {column_candidate => 1}
                end
                inferred_table_columns_by_raw_where_clause[raw_where_clause] << [current_table,column_candidate]
              else
                non_matches << identifier
              end
            end
          end
        end
      end
      {:queried_columns_by_table => queried_columns_by_table,
        :inferred_table_columns_by_raw_where_clause => inferred_table_columns_by_raw_where_clause}
    end

    def hash_of_arrays
      Hash.new {|h, k| h[k] = [] }
    end

    def hash_of_hashes
      Hash.new {|h, k| h[k] = Hash.new }
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

    def sh_dbg cmd
      puts "Shelling:   #{cmd}"
      `#{cmd}`
    end
  end
end
