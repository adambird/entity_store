module EntityStore
  class NotFound < StandardError
    def initialize(id)
      super("no item with id #{id} could be found")
    end
  end
end
