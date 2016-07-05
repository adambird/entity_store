require 'sequel'
require 'uri'
require 'json'

module EntityStore
  class PostgresEntityStore
    include Logging

    Sequel.extension :pg_array_ops
    Sequel.extension :pg_json_ops

    class << self
      attr_accessor :connection_profile
      attr_writer :connect_timeout

      def database
        @_database ||= Sequel.connect('postgres://localhost/cronofy_test')
        @_database.extension :pg_array
        @_database.extension :pg_json

        @_database
      end
    end

    def open
      PostgresEntityStore.database
    end

    def entities
      return @entities_collection if @entities_collection

      unless open.table_exists?(:entities)
        open.create_table :entities do
          String :id
          String :_type
          integer :snapshot_key
          integer :version
          column :snapshot, :jsonb
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
          column :data, :jsonb
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
        .update(:snapshot => TypedJSON.generate(entity.attributes), :snapshot_key => snapshot_key )
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
      # Hack to ensure that pg_json is loaded :(
      open
      items.each do |event|
        doc = {
          :id => BSON::ObjectId.new.to_s,
          :_type => event.class.name,
          :_entity_id => BSON::ObjectId.from_string(event.entity_id).to_s,
          :entity_version => event.entity_version,
          :data => TypedJSON.generate(event.attributes),
        }
        events.insert(doc)
      end
    end

    class TypedJSON
      def self.generate(obj, *args)
        hash_dup = each_with_parent(obj)
        JSON.generate(hash_dup, *args)
      end

      def self.map_to_json(obj)
        case obj
        when Time
          JSONTime.new(obj)
        when Date
          JSONDate.new(obj)
        when DateTime
          JSONDateTime.new(obj)
        when Symbol
          JSONSymbol.new(obj)
        else
          obj
        end
      end

      def self.each_with_parent(hash, result=nil)
        duplicated_hash = {} || result

        hash.each do |k, v|
          case v
          when Hash
            duplicated_hash[k] = each_with_parent(v, duplicated_hash)
          else
            duplicated_hash[k] = map_to_json(v)
          end
        end

        duplicated_hash
      end
    end

    class JSONSymbol < SimpleDelegator
      # Returns a hash, that will be turned into a JSON object and represent this
      # object.
      def as_json(*)
        {
          JSON.create_id => self.class.name,
          's'            => to_s,
        }
      end

      # Stores class name (Symbol) with String representation of Symbol as a JSON string.
      def to_json(*a)
        as_json.to_json(*a)
      end

      # Deserializes JSON string by converting the <tt>string</tt> value stored in the object to a Symbol
      def self.json_create(o)
        o['s'].to_sym
      end
    end

    class JSONTime < SimpleDelegator
      # Deserializes JSON string by converting time since epoch to Time
      def self.json_create(object)
        if usec = object.delete('u') # used to be tv_usec -> tv_nsec
          object['n'] = usec * 1000
        end
        if method_defined?(:tv_nsec)
          Time.at(object['s'], Time.Rational(object['n'], 1000))
        else
          Time.at(object['s'], object['n'] / 1000)
        end
      end

      # Returns a hash, that will be turned into a JSON object and represent this
      # object.
      def as_json(*)
        nanoseconds = [ tv_usec * 1000 ]
        respond_to?(:tv_nsec) and nanoseconds << tv_nsec
        nanoseconds = nanoseconds.max
        {
          JSON.create_id => self.class.name,
          's'            => tv_sec,
          'n'            => nanoseconds,
        }
      end

      # Stores class name (Time) with number of seconds since epoch and number of
      # microseconds for Time as JSON string
      def to_json(*args)
        as_json.to_json(*args)
      end
    end

    class JSONDate < SimpleDelegator
      # Deserializes JSON string by converting Julian year <tt>y</tt>, month
      # <tt>m</tt>, day <tt>d</tt> and Day of Calendar Reform <tt>sg</tt> to Date.
      def self.json_create(object)
        Date.civil(*object.values_at('y', 'm', 'd', 'sg'))
      end

      #alias start sg unless method_defined?(:start)

      # Returns a hash, that will be turned into a JSON object and represent this
      # object.
      def as_json(*)
        {
          JSON.create_id => self.class.name,
          'y' => year,
          'm' => month,
          'd' => day,
          'sg' => start,
        }
      end

      # Stores class name (Date) with Julian year <tt>y</tt>, month <tt>m</tt>, day
      # <tt>d</tt> and Day of Calendar Reform <tt>sg</tt> as JSON string
      def to_json(*args)
        as_json.to_json(*args)
      end
    end

    class JSONDateTime < SimpleDelegator
      # Deserializes JSON string by converting year <tt>y</tt>, month <tt>m</tt>,
      # day <tt>d</tt>, hour <tt>H</tt>, minute <tt>M</tt>, second <tt>S</tt>,
      # offset <tt>of</tt> and Day of Calendar Reform <tt>sg</tt> to DateTime.
      def self.json_create(object)
        args = object.values_at('y', 'm', 'd', 'H', 'M', 'S')
        of_a, of_b = object['of'].split('/')
        if of_b and of_b != '0'
          args << DateTime.Rational(of_a.to_i, of_b.to_i)
        else
          args << of_a
        end
        args << object['sg']
        DateTime.civil(*args)
      end

      #alias start sg unless method_defined?(:start)

      # Returns a hash, that will be turned into a JSON object and represent this
      # object.
      def as_json(*)
        {
          JSON.create_id => self.class.name,
          'y' => year,
          'm' => month,
          'd' => day,
          'H' => hour,
          'M' => min,
          'S' => sec,
          'of' => offset.to_s,
          'sg' => start,
        }
      end

      # Stores class name (DateTime) with Julian year <tt>y</tt>, month <tt>m</tt>,
      # day <tt>d</tt>, hour <tt>H</tt>, minute <tt>M</tt>, second <tt>S</tt>,
      # offset <tt>of</tt> and Day of Calendar Reform <tt>sg</tt> as JSON string
      def to_json(*args)
        as_json.to_json(*args)
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
      # not actually needed
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
            hash = JSON.load(Sequel.object_to_json(attrs[:snapshot]))
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
            hash = JSON.load(Sequel.object_to_json(attrs[:data]))
            EntityStore::Config.load_type(attrs[:_type]).new(hash)
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
