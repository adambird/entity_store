require 'spec_helper'

describe MongoEntityStore do
  describe "#get_entity!" do
    context "when invalid id format passed" do
      before(:each) do
        @store = MongoEntityStore.new
      end
      
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
  
end
