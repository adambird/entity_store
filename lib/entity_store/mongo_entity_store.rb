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
        @_connection ||= Mongo::MongoClient.from_uri(MongoEntityStore.connection_profile, :connect_timeout => EntityStore::Config.connect_timeout, :refresh_mode => :sync)
      end

      def database
        @_database ||= MongoEntityStore.connection_profile.split('/').last.split('?').first
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

    def add_entity(entity, id = BSON::ObjectId.new)
      entities.insert('_id' => id, '_type' => entity.class.name, 'version' => entity.version).to_s
    end

    def save_entity(entity)
      entities.update({'_id' => BSON::ObjectId.from_string(entity.id)}, { '$set' => { 'version' => entity.version } })
    end

    # Public: create a snapshot of the entity and store in the entities collection
    #
    def snapshot_entity(entity)
      query = {'_id' => BSON::ObjectId.from_string(entity.id)}
      updates = { '$set' => { 'snapshot' => entity.attributes } }

      if entity.class.respond_to? :entity_store_snapshot_key
        # If there is a snapshot key, store it too
        updates['$set']['snapshot_key'] = entity.class.entity_store_snapshot_key
      else
        # Otherwise, make sure there isn't one set
        updates['$unset'] = { 'snapshot_key' => '' }
      end

      entities.update(query, updates, { :upsert => true} )
    end

    # Public - remove the snapshot for an entity
    #
    def remove_entity_snapshot(id)
      entities.update({'_id' => BSON::ObjectId.from_string(id)}, { '$unset' => { 'snapshot' => 1}})
    end

    # Public: remove all snapshots
    #
    # type        - String optional class name for the entity
    #
    def remove_snapshots type=nil
      query = {}
      query['_type'] = type if type
      entities.update(query, { '$unset' => { 'snapshot' => 1 } }, { multi: true })
    end

    def add_events(items)
      events_with_id = items.map { |e| [ BSON::ObjectId.new, e ] }
      add_events_with_ids(events_with_id)
    end

    def add_events_with_ids(event_id_map)
      docs = event_id_map.map do |id, event|
        {
          '_id' => id,
          '_type' => event.class.name,
          '_entity_id' => BSON::ObjectId.from_string(event.entity_id)
        }.merge(event.attributes)
      end

      events.insert(docs)
    end

    # Public: loads the entity from the store, including any available snapshots
    # then loads the events to complete the state
    #
    # ids           - Array of Strings representation of BSON::ObjectId
    # options       - Hash of options (default: {})
    #                 :raise_exception - Boolean (default: true)
    #
    # Returns an array of entities
    def get_entities(ids, options={})

      object_ids = ids.map do |id|
        begin
          BSON::ObjectId.from_string(id)
        rescue BSON::InvalidObjectId
          raise NotFound.new(id) if options.fetch(:raise_exception, true)
          nil
        end
      end

      entities.find('_id' => { '$in' => object_ids }).map do |attrs|
        begin
          entity_type = EntityStore::Config.load_type(attrs['_type'])

          # Check if there is a snapshot key in use
          if entity_type.respond_to? :entity_store_snapshot_key
            active_key = entity_type.entity_store_snapshot_key
            # Discard the snapshot if the keys don't match
            attrs.delete('snapshot') unless active_key == attrs['snapshot_key']
          end

          entity = entity_type.new(attrs['snapshot'] || {'id' => attrs['_id'].to_s })
        rescue => e
          log_error "Error loading type #{attrs['_type']}", e
          raise
        end

        entity
      end

    end

    # Public:  get events for an array of criteria objects
    #           because each entity could have a different reference
    #           version this allows optional criteria to be specifed
    #
    #
    # criteria  - Hash :id mandatory, :since_version optional
    #
    # Examples
    #
    # get_events_for_criteria([ { id: "23232323"}, { id: "2398429834", since_version: 4 } ] )
    #
    # Returns Hash with id as key and Array of Event instances as value
    def get_events(criteria)
      return {} if criteria.empty?

      query_items = criteria.map do |item|
        raise ArgumentError.new(":id missing from criteria") unless item[:id]
        item_query = { '_entity_id' => BSON::ObjectId.from_string(item[:id]) }
        item_query['entity_version'] = { '$gt' => item[:since_version] } if item[:since_version]
        item_query
      end

      query = { '$or' => query_items }

      result = Hash[ criteria.map { |item| [ item[:id], [] ] } ]

      events.find(query).each do |attrs|
        result[attrs['_entity_id'].to_s] << attrs
      end

      result.each do |id, events|
        # Have to do the sort client side as otherwise the query will not use
        # indexes (http://docs.mongodb.org/manual/reference/operator/query/or/#or-and-sort-operations)
        events.sort_by! { |attrs| [attrs['entity_version'], attrs['_id'].to_s] }

        # Convert the attributes into event objects
        events.map! do |attrs|
          begin
            EntityStore::Config.load_type(attrs['_type']).new(attrs)
          rescue => e
            log_error "Error loading type #{attrs['_type']}", e
            nil
          end
        end

        events.compact!
      end

      result
    end
  end
end
