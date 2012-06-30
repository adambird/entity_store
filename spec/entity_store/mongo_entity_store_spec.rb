require 'spec_helper'

module Level1
  module Level2
    class MyClass
    end
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
      before(:each) do
        @store = MongoEntityStore.new
      end
      
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
end
