module SuggestDbIndices
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join File.dirname(__FILE__), '../tasks/suggest_db_indices.rake'
    end
  end
end
