module EntityStore
  module Config
    class << self
      # Stores
      attr_accessor :store, :feed_store

      # Allows config to pass in a lambda or Proc to use as the type loader in place
      # of the default. 
      # Original use case was migration of entity classes to new module namespace when 
      # extracting to a shared library
      attr_accessor :type_loader

      # Logger can be assigned
      attr_writer :logger

      def setup
        yield self

        raise StandardError.new("store not assigned") unless store
        store.open 
        feed_store.open if feed_store
      end
      
      def event_subscribers
        @_event_subscribers ||=[]
      end
      
      # Public - indicates the version increment that is used to 
      # decided whether a snapshot of an entity should be created when it's saved
      def snapshot_threshold
        @_snapshot_threshold ||= 10
      end

      def snapshot_threshold=(value)
        @_snapshot_threshold = value
      end

      
      def load_type(type_name)
        if EntityStore::Config.type_loader
          EntityStore::Config.type_loader.call(type_name)
        else
          type_name.split('::').inject(Object) {|obj, name| obj.const_get(name) }
        end
      end

      def connect_timeout
        (ENV['ENTITY_STORE_CONNECT_TIMEOUT'] || '2').to_i
      end

      def logger
        unless @logger
          require 'logger'
          @logger = ::Logger.new(STDOUT)
          @logger.level = ::Logger::INFO
        end
        @logger 
      end

    end

  end
end