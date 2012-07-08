desc "Generate a migration that adds missing indices"
task :suggest_db_indices => :environment do
  SuggestDbIndices.go!
end
