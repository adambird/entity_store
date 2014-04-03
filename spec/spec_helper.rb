require 'rake'
require 'rspec'
require 'mongo'
require 'hatchet'

require "#{Rake.application.original_dir}/lib/entity_store"

RSpec.configure do |config|
  config.color_enabled = true
end

include EntityStore

Hatchet.configure do |config|
  config.level :fatal
  config.formatter = Hatchet::SimpleFormatter.new
  config.appenders << Hatchet::LoggerAppender.new do |appender|
    appender.logger = Logger.new(STDOUT)
  end
end
include Hatchet

EntityStore::Config.logger = log

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
  BSON::ObjectId.from_time(random_time, :unique => true).to_s
end
