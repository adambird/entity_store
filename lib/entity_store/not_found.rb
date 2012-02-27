module EntityStore
  class NotFound < StandardError
    def initialise(id)
      super("no item with id #{id} could be found")
    end
  end
end