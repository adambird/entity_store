require 'spec_helper'

class DummyEntity
  include Entity

  attr_accessor :name

  def set_name(name)
    record_event DummyEntityNameSet.new(name: name)
  end
end

class DummyEntityNameSet
  include Event

  attr_accessor :name

  def apply(entity)
    entity.name = name
  end
end

class DummyEntitySubscriber
  class << self
    attr_accessor :event_name
  end

  def dummy_entity_name_set(event)
    DummyEntitySubscriber.event_name = event.name
  end
end

describe "end to end" do
  before(:each) do
    MongoEntityStore.connection_profile = "mongodb://localhost/entity_store_test"

    EntityStore::Config.setup do |config|
      config.store = MongoEntityStore.new
      config.event_subscribers << DummyEntitySubscriber
    end
  end

  context "when save entity" do
    let(:name) { random_string }
    before(:each) do
      @entity = DummyEntity.new
      @entity.set_name name
      @id = Store.new.save @entity
    end

    it "publishes event to the subscriber" do
      DummyEntitySubscriber.event_name.should eq(name)
    end
    it "is retrievable with the events applied" do
      EntityStore::Store.new.get(@entity.id).name.should eq(name)
    end
  end
end