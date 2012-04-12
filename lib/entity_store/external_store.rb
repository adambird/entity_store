require 'mongo'
require 'uri'

module EntityStore
  class ExternalStore
    include Mongo
    
    def open_connection
      @db ||= open_store
    end
    
    def open_store
      uri  = URI.parse(EntityStore.external_connection_profile)
      Connection.from_uri(EntityStore.external_connection_profile).db(uri.path.gsub(/^\//, ''))
    end
    
    def events
      @events_collection ||= open_connection['events']
    end
    
    def publish_event(entity_type, event)
      events.insert({
        '_entity_type' => entity_type, '_type' => event.class.name 
        }.merge(event.attributes)
      )
    end
    
    def method_name
      
    end
    
  end
end