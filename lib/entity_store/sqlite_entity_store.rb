require 'sqlite3'

module EntityStore
  class SqliteEntityStore
    include Logging

    class << self
      TABLE_EXISTS_SQL = "SELECT name FROM sqlite_master WHERE type='table' AND name= ?;"
      CREATE_ENTITIES_TABLE_SQL = "CREATE TABLE entities(id INTEGER AUTOINCREMENT PRIMARY KEY, type TEXT, version INTEGER);"
      CREATE_ENTITY_EVENTS_TABLE_SQL = "CREATE TABLE entity_events(entity_id INTEGER, type TEXT, body TEXT);"

      attr_accessor :connection_profile

      def database
        @_database ||= SqliteEntityStore.connection_profile.split('/').last
      end

      def init_database
        unless table_exists?("entities")
          database.execute(CREATE_ENTITIES_TABLE_SQL)
        end
        unless table_exists?("entity_events")
          database.execute(CREATE_ENTITY_EVENTS_TABLE_SQL)
        end
      end

      def table_exists?(table_name)
        database.get_first_row(TABLE_EXISTS_SQL, table_name)
      end

    end

    def database
      SqliteEntityStore.database
    end

    INSERT_ENTITY_SQL = "INSERT INTO entities (type, version) VALUES (?, ?);"
    UPDATE_ENTITY_SQL = "UPDATE entities SET version = ? WHERE id = ?;"

    def add_entity(entity)
      # TODO not thread safe
      database.execute(INSERT_ENTITY_SQL, [ entity.class.name, entity.version ])
      database.last_insert_row_id.to_s
    end

    def save_entity(entity)
      database.execute(UPDATE_ENTITY_SQL, [ entity.version, entity.id.to_i ])
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

      sql = "SELECT * from entites WHERE id in [#{ ids.map { "?" }.join(", ")}];"

      database.execute(sql, ids) do |row|
        puts row
        # begin
        #   entity_type = EntityStore::Config.load_type(attrs['_type'])

        #   # Check if there is a snapshot key in use
        #   if entity_type.respond_to? :entity_store_snapshot_key
        #     active_key = entity_type.entity_store_snapshot_key
        #     # Discard the snapshot if the keys don't match
        #     attrs.delete('snapshot') unless active_key == attrs['snapshot_key']
        #   end

        #   entity = entity_type.new(attrs['snapshot'] || {'id' => attrs['_id'].to_s })
        # rescue => e
        #   log_error "Error loading type #{attrs['_type']}", e
        #   raise
        # end

        # entity
      end

    end
  end
end
