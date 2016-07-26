require "#{Rake.application.original_dir}/lib/entity_store"

namespace :entity_store do
  task :ensure_indexes do
    EntityStore::MongoEntityStore.new.ensure_indexes
  end

  task :drop_db do
    EntityStore::PostgresEntityStore.new.clear
  end

  task :create_db do
    EntityStore::PostgresEntityStore.init
  end
end
