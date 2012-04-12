require 'spec_helper'

class DummyEvent
  include Event
  attr_accessor :name
end

describe EventBus do
  before(:each) do
    @entity_type = random_string
    @event = DummyEvent.new(:name => random_string)
  end
  describe ".publish" do
    before(:each) do
      @subscriber = mock("Subscriber", :dummy_event => true)
      @subscriber_class = mock("SubscriberClass", :instance_method_names => ['dummy_event'], :new => @subscriber, :name => "SubscriberClass")
      @subscriber_class2 = mock("SubscriberClass", :instance_method_names => ['bilge'], :name => "SubscriberClass")
      EventBus.stub(:subscribers).and_return([@subscriber_class, @subscriber_class2])
      EventBus.stub(:publish_externally)
    end
    
    subject { EventBus.publish(@entity_type, @event) }
    
    it "calls the receiver method on the subscriber" do
      @subscriber.should_receive(:dummy_event).with(@event)
      subject
    end
    it "should not create an instance of a class without the receiver method" do
      @subscriber_class2.should_not_receive(:new)
      subject
    end
    it "publishes event to the external event push" do
      EventBus.should_receive(:publish_externally).with(@entity_type, @event)
      subject
    end
  end
  
  describe ".publish_externally" do
    before(:each) do
      @external_store = mock(ExternalStore)
      EventBus.stub(:external_store) { @external_store }
    end
    
    subject { EventBus.publish_externally @entity_type, @event }
    
    it "should publish to the external store" do
      @external_store.should_receive(:publish_event).with(@entity_type, @event)
      subject
    end
  end
end
