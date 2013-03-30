$:.push File.expand_path("../lib", __FILE__)
require "entity_store/version"

Gem::Specification.new do |s|
  s.name        = "entity_store"
  s.version     = EntityStore::VERSION.dup
  s.platform    = Gem::Platform::RUBY 
  s.summary     = "Event sourced entity store with a replaceable body"
  s.email       = "adam.bird@gmail.com"
  s.homepage    = "http://github.com/adambird/entity_store"
  s.description = "Event sourced entity store with a replaceable body"
  s.authors     = ['Adam Bird']

  s.files         = Dir["lib/**/*"]
  s.test_files    = Dir["spec/**/*"]
  s.require_paths = ["lib"]

  s.add_dependency('hatchet', '~> 0.0.20')
end