module EntityStore
  module Utils
    def self.get_type_constant(type_name)
      type_name.split('::').inject(Object) { |obj, name| obj.const_get(name) }
    end
  end
end

