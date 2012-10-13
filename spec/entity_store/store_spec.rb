require 'spec_helper'

class DummyEntityForStore
  include Entity

  attr_accessor :name

end

describe Store do
  describe "#add" do
    before(:each) do
      @new_id = random_string
      @entity = DummyEntityForStore.new(:name => random_string)
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
      @entity = DummyEntityForStore.new(:name => random_string)
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
    context "when entity has related entities loaded" do
      before(:each) do
        @entity = DummyEntityForStore.new(:id => random_string)
        @store = Store.new
        @related_entity = mock('Entity')
        @entity.stub(:loaded_related_entities) { [ @related_entity ] }
        @store.stub(:do_save)
      end
      
      subject { @store.save(@entity) }

      it "should save the entity" do
        @store.should_receive(:do_save).with(@entity)
        subject
      end
      it "should save them as well" do
        @store.should_receive(:do_save).with(@related_entity)
        subject
      end
    end

  end

  describe "#do_save" do
    before(:each) do
      @new_id = random_string
      @entity = DummyEntityForStore.new(:id => random_string)
      @storage_client = mock("StorageClient", :save_entity => true)
      @store = Store.new
      @store.stub(:add_events)
      @store.stub(:storage_client) { @storage_client }
      @entity.stub(:pending_events) { [ mock('Event') ] }
    end

    subject { @store.do_save(@entity) }

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
    it "returns a reference to the entity" do
      subject.should eq(@entity)
    end
    context "when no pending events" do
      before(:each) do
        @entity.stub(:pending_events) { [] }
      end
      it "should not save the entity" do
        @storage_client.should_not_receive(:save_entity)
        subject
      end
      it "should not add the events" do
        @storage_client.should_not_receive(:add_events)
        subject
      end
    end
    context "when entity doesn't have an id" do
      before(:each) do
        @entity.id = nil
        @id = random_string
        @storage_client.stub(:add_entity) { @id }
      end
      it "should add the entity" do
        @storage_client.should_receive(:add_entity).with(@entity)
        subject
      end
    end
  end

  describe "#get" do
    before(:each) do
      @id = random_integer
      @entity = DummyEntityForStore.new
      DummyEntityForStore.stub(:new).and_return(@ride)
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
    it "should assign itself as the related_entity_loader" do
      subject.related_entity_loader.should eq(@store)
    end
    it "should return a ride" do
      subject.should eq(@entity)
    end
  end
end
