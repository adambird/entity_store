require 'spec_helper'

module Level1
  module Level2
    class MyClass
    end
  end
end

module MongoEntityStoreSpec
  class DummyEntity
    include Entity

    attr_accessor :name, :description

  end
end

describe MongoEntityStore do
  before(:each) do
    EntityStore.connection_profile = "mongodb://localhost/entity_store_default"
    @store = MongoEntityStore.new
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
  
  describe "get_type_constant" do
    
    subject { @store.get_type_constant('Level1::Level2::MyClass') }
    
    it "should be an Level1::Level2::MyClass" do
      subject.should eq(Level1::Level2::MyClass)
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
      saved_entity['name'].should eq(@entity.name)
      saved_entity['description'].should eq(@entity.description)
    end
  end
end
