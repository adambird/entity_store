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
    
    def collection
      @_collection ||= open_connection['events']
    end
    
    def ensure_indexes
      collection.ensure_index([['_type', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])      
    end
    
    def add_event(entity_type, event)
      collection.insert({
        '_entity_type' => entity_type, '_type' => event.class.name 
        }.merge(event.attributes)
      )
    end
    
    # Public - get events since a Time or ID
    # 
    # since         - Time or String id to filter events from 
    # type          - String optionally filter the event type to return (default=nil)
    # max_items     - Fixnum max items to return (default=100)
    # 
    # Returns Enumerable EventDataObject
    def get_events(since, type=nil, max_items=100)
      since_id = since.is_a?(Time) ? BSON::ObjectId.from_time(since) : BSON::ObjectId.from_string(since)

      query = { '_id' => { '$gt' => since_id } }
      query['_type'] = type if type
      
      options = {
        :sort => [['_id', Mongo::ASCENDING]],
        :limit => max_items
      }
      
      collection.find(query, options).collect { |e| EventDataObject.new(e)}
    end
    
  end
end