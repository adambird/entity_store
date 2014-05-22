module EntityStore

  require_relative 'entity_store/utils'
  require_relative 'entity_store/logging'
  require_relative 'entity_store/config'
  require_relative 'entity_store/time_factory'
  require_relative 'entity_store/event'
  require_relative 'entity_store/attributes'
  require_relative 'entity_store/hash_serialization'
  require_relative 'entity_store/entity'
  require_relative 'entity_store/entity_value'
  require_relative 'entity_store/store'
  require_relative 'entity_store/event_data_object'
  require_relative 'entity_store/event_bus'
  require_relative 'entity_store/not_found'

  if defined?(Mongo)
    require_relative 'entity_store/mongo_entity_store'
    require_relative 'entity_store/external_store'
  end

  # if defined?(SQLite3)
    require_relative 'entity_store/sqlite_entity_store'
  # end

  class << self
    def setup
      yield EntityStore::Config.setup
    end

    def event_subscribers
      EntityStore::Config.event_subscribers
    end
  end

end
