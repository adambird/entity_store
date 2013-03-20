require 'mongo'
require 'uri'

module EntityStore
  class MongoEntityStore
    include Mongo
    include Hatchet

    class << self
      attr_accessor :connection_profile
      attr_writer :connect_timeout

      def connection
        @_connection ||= Mongo::MongoClient.from_uri(MongoEntityStore.connection_profile, :connect_timeout => EntityStore.connect_timeout)
      end

      def database
        URI.parse(MongoEntityStore.connection_profile).path.gsub(/^\//, '')
      end
    end

    def open
      MongoEntityStore.connection.db(MongoEntityStore.database)
    end

    def entities
      @entities_collection ||= open['entities']
    end

    def events
      @events_collection ||= open['entity_events']
    end

    def ensure_indexes
      events.ensure_index([['_entity_id', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
      events.ensure_index([['_entity_id', Mongo::ASCENDING], ['entity_version', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
    end

    def add_entity(entity)
      entities.insert('_type' => entity.class.name, 'version' => entity.version).to_s
    end

    def save_entity(entity)
      entities.update({'_id' => BSON::ObjectId.from_string(entity.id)}, { '$set' => { 'version' => entity.version } })
    end

    # Public - create a snapshot of the entity and store in the entities collection
    # 
    def snapshot_entity(entity)
      query = {'_id' => BSON::ObjectId.from_string(entity.id)}
      updates = { '$set' => { 'snapshot' => entity.attributes } }
      entities.update(query, updates, { :upsert => true} )
    end

    # Public - remove the snapshot for an entity
    # 
    def remove_entity_snapshot(id)
      entities.update({'_id' => BSON::ObjectId.from_string(id)}, { '$unset' => { 'snapshot' => 1}})
    end

    def add_event(event)
      events.insert({'_type' => event.class.name, '_entity_id' => BSON::ObjectId.from_string(event.entity_id) }.merge(event.attributes) ).to_s
    end

    def get_entity!(id)
      get_entity(id, true)
    end

    # Public - loads the entity from the store, including any available snapshots
    # then loads the events to complete the state
    # 
    # id                - String representation of BSON::ObjectId
    # raise_exception   - Boolean indicating whether to raise an exception if not found (default=false)
    # 
    # Returns an object of the entity type
    def get_entity(id, raise_exception=false)
      if attrs = entities.find_one('_id' => BSON::ObjectId.from_string(id))
        begin
          entity = EntityStore.load_type(attrs['_type']).new(attrs['snapshot'] || {'id' => id, 'version' => attrs['version']})
        rescue => e
          logger.error "Error loading type #{attrs['_type']}", e
          raise
        end

        since_version = attrs['snapshot'] ? attrs['snapshot']['version'] : nil

        get_events(id, since_version).each do |event| 
          begin
            event.apply(entity) 
            logger.debug { "Applied #{event.inspect} to #{id}" }
          rescue => e
            logger.error "Failed to apply #{event.class.name} #{event.attributes} to #{id} with #{e.inspect}", e
          end
          entity.version = event.entity_version
        end

        entity
      else
        raise NotFound.new(id) if raise_exception
        nil
      end
    rescue BSON::InvalidObjectId
      raise NotFound.new(id) if raise_exception
      nil
    end

    def get_events(id, since_version=nil)

      query = { '_entity_id' => BSON::ObjectId.from_string(id) }
      query['entity_version'] = { '$gt' => since_version } if since_version

      options = {
        :sort => [['entity_version', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]]
      }

      events.find(query, options).collect do |attrs|
        begin
          EntityStore.load_type(attrs['_type']).new(attrs)
        rescue => e
          logger.error "Error loading type #{attrs['_type']}", e
          nil
        end
      end.select { |e| !e.nil? }
    end

  end
end
