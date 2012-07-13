require 'spec_helper'

class DummyEntity
  include Entity

  attr_accessor :name

  def initialize(name)
    @name = name
  end
end

describe Store do
  describe "#add" do
    before(:each) do
      @new_id = random_string
      @entity = DummyEntity.new(random_string)
      @storage_client = mock("StorageClient", :add_entity => @new_id)
      @store = Store.new
      @store.stub(:add_events)
      @store.stub(:storage_client) { @storage_client }
    end

    subject { @store.add(@entity) }

    it "adds the new entity to the store" do
      @storage_client.should_receive(:add_entity).with(@entity)
      subject
    end
    it "adds events" do
      @store.should_receive(:add_events).with(@entity)
      subject
    end
    it "returns a reference to the ride" do
      subject.should eq(@entity)
    end
  end

  describe "#add_events" do
    before(:each) do
      @entity = DummyEntity.new(random_string)
      @entity.id = random_string
      @entity.version = random_integer
      @entity.pending_events << mock(Event, :entity_id= => true, :entity_version= => true)
      @entity.pending_events << mock(Event, :entity_id= => true, :entity_version= => true)
      @storage_client = mock("StorageClient", :add_event => true)
      @store = Store.new
      @store.stub(:storage_client) { @storage_client }
      EventBus.stub(:publish)
    end

    subject { @store.add_events(@entity) }

    it "adds each of the events" do
      @entity.pending_events.each do |e|
        @storage_client.should_receive(:add_event).with(e)
      end
      subject
    end
    it "should assign the new entity_id to each event" do
      @entity.pending_events.each do |e|
        e.should_receive(:entity_id=).with(@entity.id)
      end
      subject
    end
    it "should assign the current entity version to each event" do
      @entity.pending_events.each do |e|
        e.should_receive(:entity_version=).with(@entity.version)
      end
      subject
    end
    it "publishes each event to the EventBus" do
      @entity.pending_events.each do |e|
        EventBus.should_receive(:publish).with(@entity.type, e)
      end
      subject
    end

  end

  describe "#save" do
    before(:each) do
      @new_id = random_string
      @entity = DummyEntity.new(random_string)
      @storage_client = mock("StorageClient", :save_entity => true)
      @store = Store.new
      @store.stub(:add_events)
      @store.stub(:storage_client) { @storage_client }
    end

    subject { @store.save(@entity) }

    it "increments the entity version number" do
      @entity.should_receive(:version=).with(@entity.version + 1)
      subject
    end
    it "save the new entity to the store" do
      @storage_client.should_receive(:save_entity).with(@entity)
      subject
    end
    it "adds events" do
      @store.should_receive(:add_events).with(@entity)
      subject
    end
    it "returns a reference to the ride" do
      subject.should eq(@entity)
    end
  end

  describe "#get" do
    before(:each) do
      @id = random_integer
      @entity = DummyEntity.new(random_string)
      DummyEntity.stub(:new).and_return(@ride)
      @events = [mock("Event", :apply => true), mock("Event", :apply => true)]

      @storage_client = mock("StorageClient", :get_entity => @entity, :get_events => @events)
      @store = Store.new
      @store.stub(:storage_client) { @storage_client }
    end

    subject { @store.get(@id) }

    it "should retrieve object from the storage client" do
      @storage_client.should_receive(:get_entity).with(@id, false)
      subject
    end
    it "should retrieve the events for the entity" do
      @storage_client.should_receive(:get_events).with(@id)
      subject
    end
    it "should apply each event" do
      @events.each do |e|
        e.should_receive(:apply).with(@entity)
      end
      subject
    end
    it "should return a ride" do
      subject.should eq(@entity)
    end
  end
end
