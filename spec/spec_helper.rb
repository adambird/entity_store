require 'rake'
require 'rspec'
require "#{Rake.application.original_dir}/lib/entity_store"

RSpec.configure do |config|
  config.color_enabled = true
end

Hatchet.configure do |config|
  # Reset the logging configuration
  config.reset!
  config.level :error
  # Use the format without time, etc so we don't duplicate it
  config.formatter = Hatchet::SimpleFormatter.new
  # Set up a STDOUT appender
  config.appenders << Hatchet::LoggerAppender.new do |appender|
    appender.logger = Logger.new(STDOUT)
  end
end

EntityStore.setup do |config|
  config.connection_profile = "mongodb://localhost/entity_store_test" 
  config.external_connection_profile = "mongodb://localhost/external_entity_store_test" 
end

def random_string
  (0...24).map{ ('a'..'z').to_a[rand(26)] }.join
end

def random_integer
  rand(9999)
end

def random_time
  Time.now - random_integer
end

def random_object_id
  BSON::ObjectId.from_time(random_time).to_s
end