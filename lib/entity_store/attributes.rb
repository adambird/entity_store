module EntityStore
  module Attributes
    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      def entity_value_attribute(name, klass)
        define_method(name) { instance_variable_get("@#{name}") }
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", value.is_a?(Hash) ? klass.new(value) : value)
        end
      end
    end
  end
end
