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
