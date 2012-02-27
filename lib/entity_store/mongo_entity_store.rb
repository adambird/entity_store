require 'mongo'
require 'uri'

module EntityStore
  class MongoEntityStore
    include Mongo

    def open_connection
      @db ||= open_store
    end
    
    def open_store
      uri  = URI.parse(EntityStore.connection_profile)
      Connection.from_uri(EntityStore.connection_profile).db(uri.path.gsub(/^\//, ''))
    end
    
    def entities
      @entities_collection ||= open_connection['entities']
    end
    
    def events
      return @events_collection if @events_collection
      
      @events_collection = open_connection['entity_events']
      @events_collection.ensure_index([['entity_id', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
      
      return @events_collection
    end
    
    def add_entity(entity)
      entities.insert('_type' => entity.class.name, 'version' => entity.version).to_s
    end
    
    def save_entity(entity)
      entities.update({'_id' => BSON::ObjectId.from_string(entity.id)}, { '$set' => { 'version' => entity.version } })
    end
    
    def add_event(event)
      events.insert({'_type' => event.class.name, '_entity_id' => BSON::ObjectId.from_string(event.entity_id)}.merge(event.attributes) ).to_s
    end
    
    def get_entity!(id)
      get_entity(id, true)
    end
    
    def get_entity(id, raise_exception=false)
      begin
        if attrs = entities.find('_id' => BSON::ObjectId.from_string(id)).first
          attrs['_type'].constantize.new('id' => id, 'version' => attrs['version'])
        else
          if raise_exception
            raise NotFound.new(id)
          else
            return nil
          end
        end
      rescue BSON::InvalidObjectId
        if raise_exception
          raise NotFound.new(id)
        else
          return nil
        end
      end
    end

    def get_events(id)
      events.find('_entity_id' => BSON::ObjectId.from_string(id)).collect {|attrs| attrs['_type'].constantize.new(attrs) }
    end
  end
end