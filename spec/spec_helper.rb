require 'rake'
require 'rspec'
require 'mongo'
require "#{Rake.application.original_dir}/lib/entity_store"

RSpec.configure do |config|
  config.color_enabled = true
end

include EntityStore

require 'logger'
logger = ::Logger.new(STDOUT)
logger.level = ::Logger::ERROR
EntityStore::Config.logger = logger

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