require 'mongo'
require 'uri'

module EntityStore
  class MongoEntityStore
    include Mongo
    include Logging

    class << self
      attr_accessor :connection_profile
      attr_writer :connect_timeout

      def connection
        @_connection ||= Mongo::MongoClient.from_uri(MongoEntityStore.connection_profile, :connect_timeout => EntityStore::Config.connect_timeout)
      end

      def database
        @_database ||= MongoEntityStore.connection_profile.split('/').last
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

    def clear
      entities.drop
      @entities_collection = nil
      events.drop
      @events_collection = nil
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

    # Public - remove all snapshots
    #
    # type        - String optional class name for the entity
    #
    def remove_snapshots type=nil
      query = {}
      query['_type'] = type if type
      entities.update(query, { '$unset' => { 'snapshot' => 1 } }, { multi: true })
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
          entity_type = EntityStore::Config.load_type(attrs['_type'])
          entity = entity_type.new(attrs['snapshot'] || {'id' => id })
        rescue => e
          log_error "Error loading type #{attrs['_type']}", e
          raise
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

      loaded_events = events.find(query, options).collect do |attrs|
        begin
          EntityStore::Config.load_type(attrs['_type']).new(attrs)
        rescue => e
          log_error "Error loading type #{attrs['_type']}", e
          nil
        end
      end

      loaded_events.compact
    end
  end
end
