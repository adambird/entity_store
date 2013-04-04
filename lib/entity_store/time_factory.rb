module EntityStore
  module TimeFactory
    def self.parse(value)
      require 'time'
      Time.parse(value)
    end
  end
end