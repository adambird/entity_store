require 'time' if respond_to?(:require)

module EntityStore
  module Event
    attr_accessor :entity_id, :entity_version

    def self.included(klass)
      klass.class_eval do
        include Attributes
        include HashSerialization
        extend ClassMethods
      end
    end

    def receiver_name
      elements = self.class.name.split('::')
      elements[elements.count - 1].
         gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
         gsub(/([a-z\d])([A-Z])/,'\1_\2').
         tr("-", "_").
         downcase
    end

    module ClassMethods
      def time_attribute(*names)
        class_eval do
          names.each do |name|
            define_method "#{name}=" do |value|
              if value.kind_of?(String)
                new_value = TimeFactory.parse(value)
              else
                new_value = value
              end

              instance_variable_set "@#{name}", new_value
            end
            define_method name do
              instance_variable_get "@#{name}"
            end
          end
        end
      end

      def entity_value_attribute(name, klass)
        define_method(name) { instance_variable_get("@#{name}") }
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", value.is_a?(Hash) ? klass.new(value) : value)
        end
      end
    end

    def inspect
      "<#{self.class.name} #{self.attributes.inspect}>"
    end
  end
end
