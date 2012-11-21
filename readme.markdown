# Entity Store

[![Build Status](https://secure.travis-ci.org/adambird/entity_store.png?branch=master)](http://travis-ci.org/adambird/entity_store)

Event sourced entity store implementation using MongoDB as a back end. Split out of Bunch project in order to be shared with others.

# Usage

## Tracking state change

Rather than directly changing properties of an entity via setter methods, state change happens as a result of executing commands that spawn one or more events. It is these events that are persisted.

A typical entity would look like this

	class Tyre
		include EntityStore::Entity

		attr_accessor :pressure

		def inflate(new_pressure)
			record_event(TyreInflated.new(new_pressure))
		end
	end

The corresponding event would look like this

	class TyreInflated
		include EntityStore::Event

		attr_accessor :new_pressure

		def apply(entity)
			entity.pressure = new_pressure
		end
	end

The `record_event` method adds the event to the entity's `pending_events` queue and applies the event. 

The entity is passed the an instance of the entity store via the `save` method (new entities use `add`). This results in the pending events being persisted to the `entity_events` collection in the configured MongoDB repository.

## Subscribing to events

In order to denormalise the event subscribers need to be configured to receive events that are published to the internal event bus. 

In order to subscribe to an event then a subscriber must expose a instance method matching the event's receiver_name. This is, by default the lower case event class name with underscores between words

eg: a `TyreInflated` event is received by a `tyre_inflated` method.

## Entity Values

The EntityValue module provides extensions to support complex objects as values on attributes. For example.

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
		
		attr_accessor :first_name, :last_name, :home_address
	
		def set_home_address(address)
			record_event(HomeAddressSet.new(:home_address => address))
		end
	end
		
You'll note that a class method `entity_value_attribute` is used to mark up the corresponding event correctly. Slightly uncomfortable that this isn't a poro (plain old ruby object) class. Will investigate this later.

## Replay

Replaying of specific events to specific subscribers is possible via the `EventBus`. This will pull and apply the matching events from the `external_event_store` in the order they were inserted.

```ruby
EventBus.new.replay Time.new(2011, 11, 1), 'EventTypeName', SubscriberClass
```

The first argument is the Time from which you wish to find events from.


## Configuration

An initialiser file should contain something similar to this

	EntityStore.setup do |config|
  	config.connection_profile = "mongodb://localhost/my_cars_#{Rails.env}"
		config.event_subscribers.concat([CarDenormaliser, CarSafetyService])
	end
	
## TODO

+ Concurrency - actually do something with the version of the entity
+ Backup - make copy of all events to external store
+ Restore - restore all backed up events
		