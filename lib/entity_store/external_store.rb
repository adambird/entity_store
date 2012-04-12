require 'mongo'
require 'uri'

module EntityStore
  class ExternalStore
    include Mongo
    
    def publish_event(event)
      
    end
  end
end