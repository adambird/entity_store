require 'spec_helper'

module MongoEntityStoreSpec
  class DummyEntity
    include EntityStore::Entity

    attr_accessor :by, :name, :description

  end
end

describe MongoEntityStore do
  before(:each) do
    MongoEntityStore.connection_profile = "mongodb://localhost/entity_store_default"
    @store = MongoEntityStore.new
  end

  describe "#get_entity" do
    before(:each) do
      @id = random_object_id
      @attrs = { 
        '_type' => MongoEntityStoreSpec::DummyEntity.name, 
        'version' => @version = random_integer
      }
      @entity = MongoEntityStoreSpec::DummyEntity.new
      MongoEntityStoreSpec::DummyEntity.stub(:new) { @entity }
      @entities_collection = double('MongoCollection', :find_one => @attrs)
      @store.stub(:entities) { @entities_collection }
      @events = [
        double('Event', :apply => true, :entity_version => random_integer), double('Event', :apply => true, :entity_version => random_integer)
      ]
      @store.stub(:get_events) { @events }
    end

    subject { @store.get_entity(@id) }

    it "should attempt to retrieve the entity record from the store" do
      @entities_collection.should_receive(:find_one).with({'_id' => BSON::ObjectId.from_string(@id)})
      subject
    end
    it "should construct a new entity" do
      MongoEntityStoreSpec::DummyEntity.should_receive(:new).with({'id' => @id})
      subject
    end
    it "should return the entity" do
      subject.should eq(@entity)
    end
    context "when a snapshot exists" do
      before(:each) do
        @attrs['snapshot'] = {
          'version' => @snapshot_version = random_integer,
          'name' => @name = random_string
        }
      end
      it "should construct a new entity with from the snapshot" do
        MongoEntityStoreSpec::DummyEntity.should_receive(:new).with(@attrs['snapshot'])
        subject
      end
    end
  end

  describe "#get_entity!" do

    context "when invalid id format passed" do
      
      subject { @store.get_entity!(random_string) }
      
      it "should raise not found" do
        expect { subject }.to raise_error(NotFound)
      end
    end
    context "when valid id format passed but no object exists" do
      
      subject { @store.get_entity!(random_object_id) }
      
      it "should raise not found" do
        expect { subject }.to raise_error(NotFound)
      end
    end
    
  end
  
  describe "#snapshot_entity" do
    before(:each) do
      @entity = MongoEntityStoreSpec::DummyEntity.new(:id => random_object_id, :version => random_integer, :name => random_string)
    end

    subject { @store.snapshot_entity(@entity) }

    it "should add a snaphot to the entity record" do
      subject 
      saved_entity = @store.entities.find_one({'_id' => BSON::ObjectId.from_string(@entity.id)})['snapshot']
      saved_entity['id'].should eq(@entity.id)
      saved_entity['version'].should eq(@entity.version)
      saved_entity['by'].should be_nil
      saved_entity['name'].should eq(@entity.name)
      saved_entity['description'].should eq(@entity.description)
      saved_entity.keys.should_not include 'by'
    end
  end
end
