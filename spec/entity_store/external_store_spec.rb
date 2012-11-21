require 'spec_helper'

class DummyEvent
  include Event
  attr_accessor :name
end

class DummyEventTwo
  include Event
  attr_accessor :name
end

describe ExternalStore do
  before(:each) do
    EntityStore.external_connection_profile = "mongodb://localhost/external_entity_store_default"
    ExternalStore.new.collection.drop
    @store = ExternalStore.new
  end
  describe "#add_event" do
    before(:each) do
      @entity_type = random_string
      @event = DummyEvent.new(:name => random_string, :entity_id => random_object_id)
    end
    
    subject { @store.add_event(@entity_type, @event) }
    
    it "creates a record in the collection" do
      subject
      item = @store.collection.find_one
      item['_entity_type'].should eq(@entity_type)
      item['_type'].should eq(@event.class.name)
      item['name'].should eq(@event.name)
      item['entity_id'].should eq(@event.entity_id)
    end
  end
  
  describe "#get_events" do
    before(:each) do
      @reference_time = Time.now
      @ids = (-2..2).collect { |i| BSON::ObjectId.from_time(@reference_time + i) }

      @store.collection.insert({'_id' => @ids[0], '_type' => 'DummyEvent'})
      @store.collection.insert({'_id' => @ids[1], '_type' => 'DummyEventTwo'})
      @store.collection.insert({'_id' => @ids[2], '_type' => 'DummyEvent'})
      @store.collection.insert({'_id' => @ids[3], '_type' => 'DummyEventTwo'})
      @store.collection.insert({'_id' => @ids[4], '_type' => 'DummyEvent'})
    end
       
    subject { @store.get_events @since, @type }

    context "when time passed as since" do
      before(:each) do
        @since = @reference_time
      end
      context "when no type filter" do
        before(:each) do
          @type = nil
          @results = subject
        end
        it "returns two records" do
          @results.count.should eq(2)
        end
        it "it returns the 4th item first" do
          @results.first.id.should eq(@ids[3].to_s)
        end
        it "it returns the 5th item second" do
          @results[1].id.should eq(@ids[4].to_s)
        end
      end
      context "when type filter 'DummyEventTwo' passed" do
        before(:each) do
          @type = "DummyEventTwo"
          @results = subject
        end
        it "returns 1 record" do
          @results.count.should eq(1)
        end
        it "returns the 4th item" do
          @results.first.id.should eq(@ids[3].to_s)
        end
      end
    end

    context "when id passed as since" do
      before(:each) do
        @since = @ids[1].to_s
      end
      context "when no type filter passed" do
        before(:each) do
          @type = nil
          @results = subject
        end
        it "returns 3 records" do
          @results.count.should eq(3)
        end
        it "it returns the 3rd item first" do
          @results.first.id.should eq(@ids[2].to_s)
        end
        it "it returns the 4th item second" do
          @results[1].id.should eq(@ids[3].to_s)
        end
        it "it returns the 5th item second" do
          @results[2].id.should eq(@ids[4].to_s)
        end
      end
      context "when type filter 'DummyEvent' passed" do
        before(:each) do
          @type = "DummyEvent"
          @results = subject
        end
        it "returns 2 records" do
          @results.count.should eq(2)
        end
        it "returns the 3rd item" do
          @results.first.id.should eq(@ids[2].to_s)
        end
        it "returns the 5th item" do
          @results[1].id.should eq(@ids[4].to_s)
        end
      end
    end
  end

end
