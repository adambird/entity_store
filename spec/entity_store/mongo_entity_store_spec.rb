require 'spec_helper'

describe MongoEntityStore do
  class DummyEntity
    include EntityStore::Entity

    attr_accessor :name, :description

    def set_name(new_name)
      record_event DummyEntityNameSet.new(name: new_name)
    end
  end

  class DummyEntityNameSet
    include EntityStore::Event

    attr_accessor :name

    def apply(entity)
      entity.name = self.name
    end

    def ==(other)
      # Crude check relying on inspect, ok for tests
      self.inspect == other.inspect
    end
  end

  let(:store) do
    MongoEntityStore.connection_profile = "mongodb://localhost/entity_store_default"
    MongoEntityStore.new
  end

  describe "event storage" do
    let(:entity_id) { random_object_id }

    let(:first_event)     { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 1, :name => random_string) }
    let(:second_event)    { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 2, :name => random_string) }
    let(:third_event)     { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 3, :name => random_string) }
    let(:unrelated_event) { DummyEntityNameSet.new(:entity_id => random_object_id, :entity_version => 4, :name => random_string) }

    before do
      store.add_event(second_event)
      store.add_event(unrelated_event)
      store.add_event(first_event)
      store.add_event(third_event)
    end

    subject { store.get_events(event_entity_id, since_version) }

    context "all events" do
      let(:event_entity_id) { entity_id }
      let(:since_version) { 0 }

      it "should return the three events in order" do
        subject.should == [first_event, second_event, third_event]
      end
    end

    context "subset of events" do
      let(:event_entity_id) { entity_id }
      let(:since_version) { second_event.entity_version }

      it "should only include events greater than the given version" do
        subject.should == [ third_event ]
      end
    end

    context "no events" do
      let(:event_entity_id) { random_object_id }
      let(:since_version) { 0 }

      it "should return an empty array" do
        subject.should be_empty
      end
    end
  end

  describe "#get_entity" do
    let(:saved_entity) do
      entity = DummyEntity.new(:name => random_string, :description => random_string)
      entity.id = store.add_entity(entity)
      entity
    end

    subject { store.get_entity(saved_entity.id) }

    it "should retrieve an entity from the store with the same ID" do
      subject.id.should == saved_entity.id
    end

    it "should retrieve an entity from the store with the same class" do
      subject.class.should == saved_entity.class
    end

    it "should have the same version" do
      subject.version.should == saved_entity.version
    end

    context "when a snapshot does not exist" do
      it "should not have set the name" do
        subject.name.should be_nil
      end
    end

    context "when a snapshot exists" do
      before do
        store.snapshot_entity(saved_entity)
      end

      it "should have set the name" do
        subject.name.should == saved_entity.name
      end
    end
  end

  describe "#get_entity!" do
    context "when invalid id format passed" do
      subject { store.get_entity!(random_string) }

      it "should raise not found" do
        expect { subject }.to raise_error(NotFound)
      end
    end

    context "when valid id format passed but no object exists" do
      subject { store.get_entity!(random_object_id) }

      it "should raise not found" do
        expect { subject }.to raise_error(NotFound)
      end
    end
  end

  describe "#snapshot_entity" do
    let(:entity) do
      DummyEntity.new(:id => random_object_id, :version => random_integer, :name => random_string)
    end

    subject { store.snapshot_entity(entity) }

    it "should add a snaphot to the entity record" do
      subject
      saved_entity = store.entities.find_one({'_id' => BSON::ObjectId.from_string(entity.id)})['snapshot']
      saved_entity['id'].should eq(entity.id)
      saved_entity['version'].should eq(entity.version)
      saved_entity['name'].should eq(entity.name)
      saved_entity['description'].should eq(entity.description)
    end
  end
end
