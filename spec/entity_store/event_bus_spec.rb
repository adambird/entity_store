require 'spec_helper'

class DummyEvent
  include Event
  attr_accessor :name
end

class DummySubscriber
  def dummy_event
    
  end
end

describe EventBus do
  before(:each) do
    @entity_type = random_string
    @event = DummyEvent.new(:name => random_string)
    @event_bus = EventBus.new
  end
  describe ".publish" do
    before(:each) do
      @subscriber = mock("Subscriber", :dummy_event => true)
      DummySubscriber.stub(:new) { @subscriber }
      @subscriber_class2 = mock("SubscriberClass", :instance_methods => ['bilge'], :name => "SubscriberClass")
      @event_bus.stub(:subscribers).and_return([DummySubscriber, @subscriber_class2])
      @event_bus.stub(:publish_externally)
    end
    
    subject { @event_bus.publish(@entity_type, @event) }
    
    it "calls the receiver method on the subscriber" do
      @subscriber.should_receive(:dummy_event).with(@event)
      subject
    end
    it "should not create an instance of a class without the receiver method" do
      @subscriber_class2.should_not_receive(:new)
      subject
    end
    it "publishes event to the external event push" do
      @event_bus.should_receive(:publish_externally).with(@entity_type, @event)
      subject
    end
  end
  
  describe ".publish_externally" do
    before(:each) do
      @external_store = mock(ExternalStore)
      @event_bus.stub(:external_store) { @external_store }
    end
    
    subject { @event_bus.publish_externally @entity_type, @event }
    
    it "should publish to the external store" do
      @external_store.should_receive(:add_event).with(@entity_type, @event)
      subject
    end
  end
end
