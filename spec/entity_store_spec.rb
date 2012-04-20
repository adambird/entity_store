require 'spec_helper'

describe EntityStore do
  describe ".setup" do
    before(:each) do
      EntityStore.setup do |config|
        config.log_level = Logger::WARN
      end
    end
    it "has a log_level of WARN" do
      EntityStore.log_level.should eq(Logger::WARN)
    end
  end
  
end
