# Entity Store

Event sourced entity store implementation using MongoDB as a back end. Split out of Bunch project in order to be shared with others.

# Usage

## Tracking state change

Rather than directly changing properties of an entity via setter methods, state change happens as a result of executing commands that spawn one or more events. It is these events that are persisted.

A typical entity would look like this

```ruby
class Tyre
	include EntityStore::Entity

	attr_accessor :pressure

	def inflate(new_pressure)
		record_event TyreInflated.new(new_pressure: new_pressure)
	end
end
```

The corresponding event would look like this

```ruby
class TyreInflated
	include EntityStore::Event

	attr_accessor :new_pressure

	def apply(entity)
		entity.pressure = new_pressure
	end
end
```

The `record_event` method adds the event to the entity's `pending_events` queue and applies the event. 

The entity is passed the an instance of the entity store via the `save` method (new entities use `add`). This results in the pending events being persisted to the `entity_events` collection in the configured MongoDB repository.

## Subscribing to events

In order to denormalise the event subscribers need to be configured to receive events that are published to the internal event bus. 

In order to subscribe to an event then a subscriber must expose a instance method matching the event's receiver_name. This is, by default the lower case event class name with underscores between words

eg: a `TyreInflated` event is received by a `tyre_inflated` method.

## Entity Values

The EntityValue module provides extensions to support complex objects as values on attributes. For example.

```ruby
class Address
	include EntityStore::EntityValue
	
	attr_accessor :street, :town, :county, :post_code, :country
end

class HomeAddressSet
	include EntityStore::Event
	
	entity_value_attribute :home_address, Address
	
	def	apply(entity)
		entity.home_address = home_address
	end
end

class Member
	include EntityStore::Entity
	
	attr_accessor :first_name, :last_name
	entity_value_attribute :home_address, Address

	def set_home_address(address)
		record_event(HomeAddressSet.new(:home_address => address))
	end
end
```

You'll note that a class method `entity_value_attribute` is used to mark up the entity and event correctly. Slightly uncomfortable that this isn't a poro (plain old ruby object) class. This is my solution to robust serialisation of these objects. There could well be a better way.

## Snapshotting

Each time an entity is saved, it's version is incremented.

You can specify a `snapshot_threshold` while configuring the gem. This will cause a snapshot to be created and attached to the entity record. When an entity is retrieved from the data store, only events post the snapshot version will be retrieved and applied to the entity.

## Replay

Replaying of specific events to specific subscribers is possible via the `EventBus`. This will pull and apply the matching events from the `external_event_store` in the order they were inserted.

```ruby
EventBus.new.replay Time.new(2011, 11, 1), 'EventTypeName', SubscriberClass
```

The first argument is the Time from which you wish to find events from.


## Configuration

An initialiser file should assign at minimum a configured `store` to use.

```ruby
EntityStore::MongoEntityStore.connection_profile = ENV['MONGO_URL'] || "mongodb://localhost/my_cars_#{Rails.env}"

EntityStore.setup do |config|
	config.store = EntityStore::MongoEntityStore.new
	config.event_subscribers.concat([CarDenormaliser, CarSafetyService])
end
```

`EntityStore.feed_store` is configured in a similar way.

You can also override the type loader used by passing a lambda or a Proc. Handy if, as in my case, you moved the entity classes to a new module namespace.

``` ruby
  config.type_loader = lambda {|type_name|
    begin 
      type_name.split('::').inject(Object) {|obj, name| obj.const_get(name) }
    rescue NameError => e
      "NewNamespace::#{type_name}".split('::').inject(Object) {|obj, name| obj.const_get(name) }
    end
  }
```

## Replace The Store

The store used is replaceable. The minimum interface requirements for the `EntityStore.store`. Types should be loaded using the `EntityStore.load_type` method *(bit smelly)*.

```ruby
class MyStore

	def add_entity(entity)
	  # this method should assign an id to the entity
	end

	def save_entity(entity)
		# this will be called if the entity has an id
	end

	def get_entity(id)
		# returns the entity as an empty shell of the appropriate type
		# if a snapshot exists then this should be returned
	end

	def get_events(id, since_version=nil)
		# returns all events in time sequence since the version if passed otherwise all
	end

	def snapshot_entity(entity)
		# create a snapshot of the entity that can be retrievd without replaying 
		# the entire event stream
	end

	def remove_entity_snapshot(id)
		# remove the snapshot so next time the entity is retrieved it replays the event stream
		# to rehhydrate the entity
	end

end
```

You can also replace the `EntityStore.feed_store` with 

```ruby
class MyFeedStore
	
	def add_event(entity_type, event)
		# entity_type is a string 
	end

	def get_events(since, type=nil, max_items=nil)
		# retrieve all events since a the DateTime passed as since
	end

end
```

## TODO

+ Concurrency - actually do something with the version of the entity
+ Backup - make copy of all events to external store
+ Restore - restore all backed up events
		