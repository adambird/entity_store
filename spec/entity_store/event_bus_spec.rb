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
      @event_bus.stub(:publish_to_feed)
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
      @event_bus.should_receive(:publish_to_feed).with(@entity_type, @event)
      subject
    end
  end
  
  describe ".publish_to_feed" do
    before(:each) do
      @feed_store = mock(ExternalStore)
      @event_bus.stub(:feed_store) { @feed_store }
    end
    
    subject { @event_bus.publish_to_feed @entity_type, @event }
    
    it "should publish to the external store" do
      @feed_store.should_receive(:add_event).with(@entity_type, @event)
      subject
    end
  end

  describe "#replay" do
    before(:each) do
      @since = random_time
      @type = 'DummyEvent'
      @subscriber = mock("Subscriber", :dummy_event => true)
      DummySubscriber.stub(:new) { @subscriber }

      @feed_store = mock(ExternalStore)
      @id = random_object_id
      @feed_store.stub(:get_events) { |since| since == @id ? [] : [
        EventDataObject.new('_id' => @id, '_type' => DummyEvent.name, 'name' => random_string) 
      ]}
      @event_bus.stub(:feed_store) { @feed_store }
    end 

    subject { @event_bus.replay(@since, @type, DummySubscriber) }

    it "gets the events for that period" do
      @feed_store.should_receive(:get_events).with(@since, @type, 100)
      subject
    end
    it "publishes them to the subscriber" do
      @subscriber.should_receive(:dummy_event).with(an_instance_of(DummyEvent))
      subject
    end
  end
end
