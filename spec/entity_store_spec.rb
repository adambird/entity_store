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
    self.class.event_name = event.name
  end
end

class AnotherEntitySubscriber
  class << self
    attr_accessor :event_name
  end

  def dummy_entity_name_set(event)
    self.class.event_name = event.name
  end
end

class DummyStore
  def open
  end

  def entities
    @entities ||= {}
  end

  def events
    @events ||= {}
  end

  def add_entity(entity, id = BSON::ObjectId.new)
    entities[id] = entity
    id.to_s
  end

  def add_events(items)
    items.each do |item|
      events[item.entity_id] ||= []
      events[item.entity_id] << item
    end
  end

  def get_entities(ids, options={})
    result = []
    ids.each do |id|
      if entity = entities[BSON::ObjectId.from_string(id)]
        result << entity
      end
    end

    result
  end

  def get_events(attrs)
    result = {}

    attrs.each do |attr|
      result[attr[:id]] = events[attr[:id]]
    end

    result
  end

  def save_entity(entity)
    entities[entity.id] = entity
  end
end

describe "creation without static instances" do
  let(:store) do
    storage_client = DummyStore.new
    Store.new(storage_client, event_bus)
  end

  let(:event_bus) do
    event_subscribers = []
    event_subscribers << AnotherEntitySubscriber

    EventBus.new(event_subscribers)
  end

  before do
    EntityStore::Config.setup do |config|
      config.store = DummyStore.new
      config.event_subscribers << DummyEntitySubscriber
    end
  end

  context "when save entity" do
    let(:name) { random_string }
    before(:each) do
      @entity = DummyEntity.new
      @entity.set_name name
      @id = store.save @entity
    end

    it "does not publish event to the non configured subscriber" do
      DummyEntitySubscriber.event_name.should_not eq(name)
    end
    it "publishes event to the subscriber" do
      AnotherEntitySubscriber.event_name.should eq(name)
    end
    it "is retrievable with the events applied" do
      store.get(@entity.id).name.should eq(name)
    end
    it "is not retrievable from the static store instance" do
      EntityStore::Store.new.get(@entity.id).should eq(nil)
    end
 end
end

describe "end to end" do
  before(:each) do
    EntityStore::Config.setup do |config|
      config.store = DummyStore.new
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
