require 'spec_helper'

class DummyEvent
  include Event
  attr_accessor :name
end

describe Event do
  describe "#attributes" do
    before(:each) do
      @id = random_integer
      @name = random_string
      @event = DummyEvent.new(:entity_id => @id, :name => @name)
    end
    
    subject { @event.attributes }
    
    it "returns a hash of the attributes" do
      subject.should eq({:entity_id => @id, :name => @name})
    end
  end
end
