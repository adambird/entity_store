module EntityStore
  module EntityValue
    def self.included(klass)
      klass.class_eval do
        include HashSerialization
        include Attributes
      end
    end

    def ==(other)
      attributes.each_key do |attr|
        return false unless other.respond_to?(attr) && send(attr) == other.send(attr)
      end
      return true
    end

  end
end
