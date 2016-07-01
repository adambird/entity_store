require 'sequel'
require 'uri'
require 'JSON'

module EntityStore
  class SqliteEntityStore
    include Logging

    class << self
      attr_accessor :connection_profile
      attr_writer :connect_timeout

      def database
        @_database ||= Sequel.sqlite
      end
    end

    def open
      SqliteEntityStore.database
    end

    def entities
      return @entities_collection if @entities_collection

      unless open.table_exists?(:entities)
        open.create_table :entities do
          String :id
          String :_type
          integer :snapshot_key
          integer :version
          text :snapshot
        end
      end

      @entities_collection ||= open[:entities]
    end

    def events
      return @events_collection if @events_collection

      unless open.table_exists?(:entity_events)
        open.create_table :entity_events do
          String :id
          String :_type
          String :_entity_id
          integer :entity_version
          text :data
        end
      end

      @events_collection ||= open[:entity_events]
    end

    def clear
      open.drop_table(:entities, :entity_events)
      @entities_collection = nil
      @events_collection = nil
    end

    def ensure_indexes
      #events.ensure_index([['_entity_id', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
      #events.ensure_index([['_entity_id', Mongo::ASCENDING], ['entity_version', Mongo::ASCENDING], ['_id', Mongo::ASCENDING]])
    end

    def add_entity(entity)
      id = BSON::ObjectId.new.to_s
      entities.insert(:id => id, :_type => entity.class.name, :version => entity.version)
      id
    end

    def save_entity(entity)
      entities.where(:id => entity.id).update(:version => entity.version)
    end

    # Public: create a snapshot of the entity and store in the entities collection
    #
    def snapshot_entity(entity)
      if entity.class.respond_to? :entity_store_snapshot_key
        # If there is a snapshot key, store it too
        snapshot_key = entity.class.entity_store_snapshot_key
      else
        # Otherwise, make sure there isn't one set
        snapshot_key = nil
      end

      unless entities[:id => entity.id]
        entities.insert(:id => entity.id, :_type => entity.class.name, :version => entity.version)
      end

      entities
        .where(:id => entity.id)
        .update(:snapshot => JSON.generate(entity.attributes), :snapshot_key => snapshot_key )
    end

    # Public - remove the snapshot for an entity
    #
    def remove_entity_snapshot(id)
      entities.where(:id => id).update(:snapshot => nil)
    end

    # Public: remove all snapshots
    #
    # type        - String optional class name for the entity
    #
    def remove_snapshots(type=nil)
      if type
        entities.where(:_type => type).update(:snapshot => nil)
      else
        entities.update(:snapshot => nil)
      end
    end

    def add_events(items)
      items.each do |event|
        doc = {
          :id => BSON::ObjectId.new.to_s,
          :_type => event.class.name,
          :_entity_id => BSON::ObjectId.from_string(event.entity_id).to_s,
          :entity_version => event.entity_version,
          :data => JSON.generate(event.attributes)
        }
        events.insert(doc)
      end
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

      entities.where(:id => ids).map do |attrs|
        begin
          entity_type = EntityStore::Config.load_type(attrs[:_type])

          # Check if there is a snapshot key in use
          if entity_type.respond_to? :entity_store_snapshot_key
            active_key = entity_type.entity_store_snapshot_key

            # Discard the snapshot if the keys don't match
            unless active_key == attrs[:snapshot_key]
              attrs.delete(:snapshot)
            end
          end

          if attrs[:snapshot]
            entity = entity_type.new(JSON.parse(attrs[:snapshot]))
          else
            entity = entity_type.new({'id' => attrs[:id].to_s })
          end
        rescue => e
          log_error "Error loading type #{attrs[:_type]}", e
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
        unless [:since_version]
          events.where(:_entity_id => item[:id]).to_a
        else
          events.where(:_entity_id => item[:id]).where('entity_version > ?', item[:since_version]).to_a
        end
      end.flatten(1)

      result = Hash[ criteria.map { |item| [ item[:id], [] ] } ]

      query_items.each do |attrs|
        result[attrs[:_entity_id].to_s] << attrs
      end

      result.each do |_, events|
        # Have to do the sort client side as otherwise the query will not use
        # indexes (http://docs.mongodb.org/manual/reference/operator/query/or/#or-and-sort-operations)
        events.sort_by! { |attrs| [attrs[:entity_version], attrs[:_id].to_s] }

        # Convert the attributes into event objects
        events.map! do |attrs|
          begin
            EntityStore::Config.load_type(attrs[:_type]).new(JSON.parse(attrs[:data]))
          rescue => e
            log_error "Error loading type #{attrs[:_type]}", e
            nil
          end
        end

        events.compact!
      end

      result
    end
  end
end
