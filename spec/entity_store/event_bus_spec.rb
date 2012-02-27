require 'spec_helper'

class DummyEvent
  include Event
  attr_accessor :name
end

describe EventBus do
  describe ".publish" do
    before(:each) do
      @event = DummyEvent.new(:name => random_string)
      @subscriber = mock("Subscriber", :dummy_event => true)
      @subscriber_class = mock("SubscriberClass", :instance_method_names => ['dummy_event'], :new => @subscriber)
      @subscriber_class2 = mock("SubscriberClass", :instance_method_names => ['bilge'])
      EventBus.stub(:subscribers).and_return([@subscriber_class, @subscriber_class2])
      EventBus.stub(:publish_externally)
    end
    
    subject { EventBus.publish(@event) }
    
    it "calls the receiver method on the subscriber" do
      @subscriber.should_receive(:dummy_event).with(@event)
      subject
    end
    it "should not create an instance of a class without the receiver method" do
      @subscriber_class2.should_not_receive(:new)
      subject
    end
    it "publishes event to the external event push" do
      EventBus.should_receive(:publish_externally).with(@event)
      subject
    end
  end
  
  describe ".publish_externally" do
    it "should publish it to external"
  end
end
