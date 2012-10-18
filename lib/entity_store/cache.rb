# Private: wrapper for the assigned cache
#
module EntityStore
  module Cache

    def cache_enabled?
      EntityStore.cache
    end

    def cache_fetch(id, version)
      cache_enabled? ? EntityStore.cache.fetch("_entity_store_#{id}_#{version}") { yield } : yield
    end
  end

end