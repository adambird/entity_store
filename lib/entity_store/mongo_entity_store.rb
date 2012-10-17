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
      connection = Connection.from_uri(EntityStore.connection_profile, :connect_timeout => connect_timeout)
      connection.db(uri.path.gsub(/^\//, ''))
    end

    def connect_timeout
      (ENV['ENTITY_STORE_CONNECT_TIMEOUT'] || '2').to_i
    end

    def entities
      @entities_collection ||= open_connection['entities']
    end

    def events
      @events_collection ||= open_connection['entity_events']
    end

    def ensure_indexes
      events.ensure_index([['entity_id', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
      events.ensure_index([['entity_id', Mongo::ASCENDING], ['entity_version', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
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
        entity = get_type_constant(attrs['_type']).new(attrs['snapshot'] || {'id' => id, 'version' => attrs['version']})

        since_version = attrs['snapshot'] ? attrs['snapshot']['version'] : nil

        get_events(id, since_version).each do |event| 
          begin
            event.apply(entity) 
          rescue => e
            EntityStore.logger.error ("Failed to apply #{event.class.name} #{e.attributes} to #{id}")
            raise e
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
          get_type_constant(attrs['_type']).new(attrs)
        rescue => e
          logger = Logger.new(STDERR)
          logger.error "Error loading type #{attrs['_type']}"
          nil
        end
      end.select { |e| !e.nil? }
    end

    def get_type_constant(type_name)
      type_name.split('::').inject(Object) {|obj, name| obj.const_get(name) }
    end
  end
end
