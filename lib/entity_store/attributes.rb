module EntityStore
  module Attributes
    def self.included klass
      klass.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      def entity_value_attribute name, klass
        define_method(name) { instance_variable_get("@#{name}") }
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", self.class._eval_entity_value_setter(value, klass))
        end
      end

      def _eval_entity_value_setter value, klass
        case value
        when Array 
          klass.new(Hash[*value.flatten])
        when Hash
          klass.new(value)
        else
          value
        end
      end

      def entity_value_array_attribute name, klass
        variable_name = "@_#{name}".to_sym

        define_method(name) do
          instance_variable_get(variable_name) || instance_variable_set(variable_name, [])
        end

        define_method("#{name}=") do |values|
          mapped_values = values.map do |value|
            case value
            when Hash
              klass.new(value)
            when klass
              value
            else
              raise ArgumentError.new("#{value.class} not supported. Expecting #{klass.name}")
            end
          end

          instance_variable_set(variable_name, mapped_values)
        end
      end

      def entity_value_dictionary_attribute name, klass
        define_method("#{name}_dictionary") {
          instance_variable_get("@_#{name}_dictionary") || instance_variable_set("@_#{name}_dictionary", {})
        }
        define_method("#{name}_dictionary=") do |value|
          value.each_pair do |key, item|
            case item
            when Hash
              send("#{name}_dictionary")[key] = klass.new(item)
            when klass
              send("#{name}_dictionary")[key] = item
            else
              raise ArgumentError.new("#{item.class.name} not supported. Expecting #{klass.name}")
            end
          end
        end
      end
    end
  end
end
