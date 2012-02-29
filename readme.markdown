# Entity Store

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

In order to denormalise the event susbcribers need to be configured to receive events that are published to the internal event bus. 

In order to subscribe to an event then a subscriber must expose a instance method matching the event's receiver_name. This is, by default the lower case event class name with underscores between words, eg: a `TyreInflated` event is received by a `tyre_inflated` method.

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
+ Replay - make it easy to replay events to new subscribers
		