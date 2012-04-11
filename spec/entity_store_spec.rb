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
  
  describe ".logger" do
    before(:each) do
      EntityStore.setup do |config|
        config.log_level = Logger::ERROR
      end
    end
    it "returns a logger with the correct log level" do
      EntityStore.logger.level.should eq(Logger::ERROR)
    end
  end
end
