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
    
    def get_events(opts={})
      query = {}
      query['_id'] = { '$gt' => opts[:after] } if opts[:after]
      query['_type'] = opts[:type] if opts[:type]
      
      options = {:sort => [['_id', -1]]}
      options[:limit] = opts[:limit] || 100
      
      collection.find(query, options).collect { |e| EventDataObject.new(e)}
    end
    
  end
end