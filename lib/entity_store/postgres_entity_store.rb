require 'sequel'
require 'uri'
require 'json'
require 'pigeon_hole'

module EntityStore
  class PostgresEntityStore
    include Logging

    Sequel.extension :pg_array_ops
    Sequel.extension :pg_json_ops

    class << self
      attr_accessor :connection_string
      attr_writer :connect_timeout

      def database
        return @_database if @_database

        @_database ||= Sequel.connect(connection_string)
        @_database.extension :pg_array
        @_database.extension :pg_json

        @_database
      end

      def init
        unless database.table_exists?(:entities)
          database.create_table :entities do
            column :id, :bytea, primary_key: true
            String :_type
            integer :snapshot_key
            integer :version
            column :snapshot, :jsonb
          end
        end

        unless database.table_exists?(:entity_events)
          database.create_table :entity_events do
            column :id, :bytea, primary_key: true
            String :_type
            column :_entity_id, :bytea
            integer :entity_version
            column :data, :jsonb
          end
        end
      end
    end

    def open
      PostgresEntityStore.database
    end

    def entities
      @entities_collection ||= open[:entities]
    end

    def events
      @events_collection ||= open[:entity_events]
    end

    def clear
      open.drop_table(:entities, :entity_events)
      @entities_collection = nil
      @events_collection = nil
    end

    def ensure_indexes
    end

    def add_entity(entity, id = BSON::ObjectId.new)
      entities.insert(:id => id.to_s, :_type => entity.class.name, :version => entity.version)
      id.to_s
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
        .update(:snapshot => PigeonHole.generate(entity.attributes), :snapshot_key => snapshot_key )
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
          :data => PigeonHole.generate(event.attributes),
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
      ids.each do |id|
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
            hash = attrs[:snapshot].to_h
            entity = entity_type.new(hash)
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

      result = {}

      criteria.each do |item|
        raise ArgumentError.new(":id missing from criteria") unless item[:id]

        query = events.where(:_entity_id => item[:id])

        if item[:since_version]
          query = query.where('entity_version > ?', item[:since_version])
        end

        result[item[:id]] = query.order(:entity_version, :id).map do |attrs|
          begin
            hash = attrs[:data].to_h
            EntityStore::Config.load_type(attrs[:_type]).new(hash)
          rescue => e
            log_error "Error loading type #{attrs[:_type]}", e
            next
          end
        end
      end

      result
    end
  end
end
