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
      @entity_type = random_string
      @events = [
        DummyEvent.new(:name => random_string, :entity_id => random_object_id),
        DummyEventTwo.new(:name => random_string, :entity_id => random_object_id),
        DummyEvent.new(:name => random_string, :entity_id => random_object_id),
        DummyEventTwo.new(:name => random_string, :entity_id => random_object_id),
        DummyEvent.new(:name => random_string, :entity_id => random_object_id)
      ]
      
      @events.each { |e| @store.add_event(@entity_type, e)}
    end
    
    context "when no options" do

      subject { @store.get_events }

      it "returns all of the events" do
        subject.count.should eq(@events.count)
      end
    end
    
    context "when options passed" do
      subject { @store.get_events(@options) }
      
      context "when limit option passed" do
        before(:each) do
          @options = {:limit => 3}
        end
        
        it "returns limited records records" do
          subject.count.should eq(@options[:limit])
        end
      end
      
      context "when after index passed" do
        before(:each) do
          items = @store.get_events(:limit => 3)
          @options = {:after => items[2].id}
        end
        
        it "returns limited records records" do
          subject.count.should eq(2)
        end
      end  
      
      context "when type passed" do
        before(:each) do
          @options = {:type => @events[2].class.name}
        end
        
        it "returns type records records" do
          subject.count.should eq(3)
        end
      end      
          
    end

  end
end
