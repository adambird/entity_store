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
      @storage_client = double("StorageClient", :add_entity => @new_id)
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
      @entity.pending_events << double(Event, :entity_id= => true, :entity_version= => true)
      @entity.pending_events << double(Event, :entity_id= => true, :entity_version= => true)
      @storage_client = double("StorageClient", :add_events => true)
      @store = Store.new
      @store.stub(:storage_client) { @storage_client }
      @event_bus = double(EventBus, :publish => true)
      @store.stub(:event_bus) { @event_bus}
    end

    subject { @store.add_events(@entity) }

    it "adds each of the events" do
      @storage_client.should_receive(:add_events).with(@entity.pending_events)
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
        @event_bus.should_receive(:publish).with(@entity.type, e)
      end
      subject
    end

  end

  describe "#upsert_events" do
    before(:each) do
      @entity = DummyEntityForStore.new(:name => random_string)
      @entity.id = random_string
      @entity.version = random_integer
      @entity.pending_events << double(Event, :entity_id => @entity.id, :entity_version => @entity.version)
      @entity.pending_events << double(Event, :entity_id => @entity.id, :entity_version => @entity.version)
      @entity.pending_events << double(Event, :entity_id => @entity.id, :entity_version => @entity.version)
      @storage_client = double("StorageClient", :upsert_events => filtered_events)
      @store = Store.new
      @store.stub(:storage_client) { @storage_client }
      @event_bus = double(EventBus, :publish => true)
      @store.stub(:event_bus) { @event_bus}
    end

    subject { @store.upsert_events(@entity) }

    let(:filtered_events) { @entity.pending_events.take(2) }

    it "adds each of the events" do
      @storage_client.should_receive(:upsert_events).with(@entity.pending_events)
      subject
    end

    it "publishes each event to the EventBus" do
      filtered_events.each do |e|
        @event_bus.should_receive(:publish).with(@entity.type, e)
      end
      subject
    end

  end

  describe "#save" do

    before(:each) do
      @new_id = random_string
      @entity = DummyEntityForStore.new(:id => random_string)
      @storage_client = double("StorageClient", :save_entity => true)
      @store = Store.new
      @store.stub(:add_events).and_yield
      @store.stub(:storage_client) { @storage_client }
      @entity.stub(:pending_events) { [ double('Event') ] }
    end

    subject { @store.save(@entity) }

    it "increments the entity version number" do
      expect { subject }.to change { @entity.version }.by 1
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
    it "should not snapshot the entity" do
      @store.should_not_receive(:snapshot_entity)
      subject
    end
    it "should publish a version incremented event" do
      @store.event_bus.should_receive(:publish).with(@entity.type, an_instance_of(DummyEntityForStoreVersionIncremented))
      subject
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

    context "when entity version is commensurate with snapshotting" do
      context "due to modulus of snapshot_threshold" do
        before(:each) do
          @entity.version = random_integer * EntityStore::Config.snapshot_threshold - 1
        end

        it "should snapshot the entity" do
          @storage_client.should_receive(:snapshot_entity).with(@entity)
          subject
        end
      end

      context "due to more than snapshot_threshold versions having passed since last snapshot" do
        before(:each) do
          starting_version = random_integer
          @entity.version = starting_version
          @entity.version = starting_version + EntityStore::Config.snapshot_threshold + 1
        end

        it "should snapshot the entity" do
          @storage_client.should_receive(:snapshot_entity).with(@entity)
          subject
        end
      end
    end

  end

  describe "getters" do
    let(:ids) { [ random_string, random_string, random_string ] }
    let(:entities) { ids.map { |id| DummyEntityForStore.new(id: id, version: random_integer) } }
    let(:events) do
      Hash[ ids.map do |id|
        [
          id,
          [
            double("Event", apply: true, entity_version: entities.find { |e| e.id == id } .version + 1),
            double("Event", apply: true, entity_version: entities.find { |e| e.id == id } .version + 2)
          ]
        ]
      end ]
    end

    let(:storage_client) { double("StorageClient") }
    let(:store) { Store.new }

    before(:each) do
      storage_client.stub(:get_entities) do |ids|
        entities.select { |e| ids.include?(e.id) }
      end

      storage_client.stub(:get_events) do |criteria|
        Hash[ criteria.map { |c| [ c[:id], events[c[:id]] ] }]
      end
      store.stub(:storage_client) { storage_client }
    end
    describe "#get" do
      let(:entity) { entities[1] }
      let(:id) { entity.id }

      subject { store.get(id) }

      it "should retrieve object from the storage client" do
        storage_client.should_receive(:get_entities).with([id], { raise_exception: false })
        subject
      end
      it "should return the entity" do
        subject.id.should eq(entity.id)
      end
      it "should apply each event to the entity" do
        events[id].each do |event|
          event.should_receive(:apply).with(entity)
        end
        subject
      end
      it "should set the entity version to that of the last event" do
        subject
        entity.version.should eq(events[id].last.entity_version)
      end
    end

    describe "#get_with_ids" do

      subject { store.get_with_ids(ids) }

      it "should retrieve object from the storage client" do
        storage_client.should_receive(:get_entities).with(ids, {})
        subject
      end
      it "should return the entities" do
        subject.map { |e| e.id }.should eq(ids)
      end
      it "should apply each event to the entities" do
        entities.each do |entity|
          events[entity.id].each do |event|
            event.should_receive(:apply).with(entity)
          end
        end
        subject
      end
      it "should set the entity version to that of the last event" do
        subject
        entities.each do |entity|
          entity.version.should eq(events[entity.id].last.entity_version)
        end
      end
    end
  end
end
