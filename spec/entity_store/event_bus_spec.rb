require 'spec_helper'

class DummyEvent
  include Event
  attr_accessor :name
end

class DummySubscriber
  def dummy_event

  end
end

class DummyStringSubscriber
  def dummy_event

  end
end

class DummyAllSubscriber
  def all_events

  end
end

class DummyExternalStore
end

describe EventBus do
  before(:each) do
    @entity_type = random_string
    @event = DummyEvent.new(:name => random_string)
    @event_bus = EventBus.new
  end
  describe ".publish" do
    before(:each) do
      @subscriber = DummySubscriber.new
      DummySubscriber.stub(:new) { @subscriber }
      @string_subscriber = DummyStringSubscriber.new
      DummyStringSubscriber.stub(:new) { @string_subscriber }
      @subscriber_class2 = double("SubscriberClass", :instance_methods => ['bilge'], :name => "SubscriberClass")
      @all_subscriber = DummyAllSubscriber.new
      DummyAllSubscriber.stub(:new) { @all_subscriber }
      EntityStore::Config.stub(:event_subscribers).and_return([DummySubscriber, @subscriber_class2, DummyAllSubscriber, 'DummyStringSubscriber'])
      @event_bus.stub(:publish_to_feed)
    end

    subject { @event_bus.publish(@entity_type, @event) }

    it "calls the receiver method on the subscriber" do
      @subscriber.should_receive(:dummy_event).with(@event)
      subject
    end
    it "calls the receiver method on the string-resolved subscriber" do
      @string_subscriber.should_receive(:dummy_event).with(@event)
      subject
    end
    it "should not create an instance of a class without the receiver method" do
      @subscriber_class2.should_not_receive(:new)
      subject
    end
    it "should call the all method of the all subscriber" do
      @all_subscriber.should_receive(:all_events).with(@event)
      subject
    end
    it "publishes event to the external event push" do
      @event_bus.should_receive(:publish_to_feed).with(@entity_type, @event)
      subject
    end
  end

  describe ".publish_to_feed" do
    before(:each) do
      @feed_store = double(DummyExternalStore)
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
      @subscriber = double("Subscriber", :dummy_event => true)
      DummySubscriber.stub(:new) { @subscriber }

      @feed_store = double(DummyExternalStore)
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
