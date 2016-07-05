require 'spec_helper'

describe PostgresEntityStore do
  class DummyEntityWithDate
    include EntityStore::Entity

    attr_accessor :name, :description, :date, :symbol, :symbol_hash
    attr_accessor :nested_hash

    def set_name(new_name)
      record_event DummyEntityNameSet.new(name: new_name)
    end
  end

  class DummyEntityWithSnapshotKey < DummyEntity
    def self.entity_store_snapshot_key
      @entity_store_snapshot_key ||= 1
    end

    def self.increment_entity_store_snapshot_key!
      @entity_store_snapshot_key = entity_store_snapshot_key + 1
    end
  end

  class DummyEntityNameSet
    include EntityStore::Event

    attr_accessor :name

    def apply(entity)
      entity.name = self.name
    end

    def ==(other)
      # Crude check relying on inspect, ok for tests
      self.inspect == other.inspect
    end
  end

  let(:store) do
    described_class.new
  end

  describe "event storage" do
    let(:entity_id) { random_object_id }

    let(:first_event)     { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 1, :name => random_string) }
    let(:second_event)    { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 2, :name => random_string) }
    let(:third_event)     { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 2, :name => random_string) }
    let(:unrelated_event) { DummyEntityNameSet.new(:entity_id => random_object_id, :entity_version => 4, :name => random_string) }
    let(:fourth_event)    { DummyEntityNameSet.new(:entity_id => entity_id, :entity_version => 3, :name => random_string) }

    before do
      store.add_events([ second_event, unrelated_event, first_event, third_event, fourth_event ])
    end

    subject { store.get_events( [{ id: event_entity_id, since_version: since_version }])[event_entity_id] }

    context "all events" do
      let(:event_entity_id) { entity_id }
      let(:since_version) { 0 }

      it "should return the four events in order" do
        subject.should == [first_event, second_event, third_event, fourth_event]
      end
    end

    context "subset of events" do
      let(:event_entity_id) { entity_id }
      let(:since_version) { second_event.entity_version }

      it "should only include events greater than the given version" do
        subject.should == [ fourth_event ]
      end
    end

    context "no events" do
      let(:event_entity_id) { random_object_id }
      let(:since_version) { 0 }

      it "should return an empty array" do
        subject.should be_empty
      end
    end
  end

  describe "#get_entities" do
    let(:entity_class) { DummyEntityWithDate }
    let(:entity_date) { random_time }

    let(:saved_entity) do
      entity = entity_class.new(
        :name => random_string,
        :description => random_string,
        :date => entity_date,
        :symbol => :foo,
        :symbol_hash => { foo: :bar },
        :nested_hash => { foo: { bar: :baz } },
      )
      entity.id = store.add_entity(entity)
      entity
    end

    let(:id) { saved_entity.id }
    let(:options) { { } }

    subject { store.get_entities( [ id ], options) }

    it "should retrieve an entity from the store with the same ID" do
      subject.first.id.should == saved_entity.id
    end

    it "should retrieve an entity from the store with the same class" do
      subject.first.class.should == saved_entity.class
    end

    it "should have the same version" do
      subject.first.version.should == saved_entity.version
    end

    context "when a snapshot does not exist" do
      it "should not have set the name" do
        subject.first.name.should be_nil
      end

      it "should not have a date set" do
        subject.first.date.should be_nil
      end

      it "should not have a symbol set" do
        subject.first.symbol.should be_nil
      end
    end

    context "when a snapshot exists" do
      before do
        saved_entity.version = 10
        store.snapshot_entity(saved_entity)
      end

      context "when a snapshot key not in use" do
        it "should have set the name" do
          subject.first.name.should == saved_entity.name
        end

        it "should have a date set" do
          subject.first.date.should == saved_entity.date
        end

        it "should have a symbol set" do
          subject.first.symbol.should == :foo
        end

        it "should have a symbol hash set" do
          subject.first.symbol_hash.should ==  { "foo" => :bar }
          subject.first.nested_hash.should ==  { "foo" => { "bar" => :baz } }
        end
      end

      context "when a snapshot key is in use" do
        let(:entity_class) { DummyEntityWithSnapshotKey }

        context "when the key matches the class's key" do
          it "should have set the name" do
            subject.first.name.should == saved_entity.name
          end
        end

        context "when the key does not match the class's key" do
          before do
            entity_class.increment_entity_store_snapshot_key!
          end

          it "should ignore the invalidated snapshot" do
            subject.first.name.should be_nil
          end
        end
      end
    end

    describe "context when enable exceptions" do
      let(:options) do
        { raise_exception: true }
      end

      context "when invalid id format passed" do
        let(:id) { random_string }

        it "should raise not found" do
          expect { subject }.to raise_error(NotFound)
        end
      end
    end

  end

  describe "#snapshot_entity" do
    let(:entity_class) { DummyEntityWithDate }

    let(:entity) do
      entity_class.new(:id => random_object_id, :version => random_integer, :name => random_string)
    end

    let(:saved_entity) do
      store.entities.where(:id => entity.id).first
    end

    let(:snapshot) { saved_entity[:snapshot] }

    subject { store.snapshot_entity(entity) }

    it "should add a snaphot to the entity record" do
      subject

      snapshot['id'].should eq(entity.id)
      snapshot['version'].should eq(entity.version)
      snapshot['name'].should eq(entity.name)
      snapshot['description'].should eq(entity.description)
    end

    context "entity with snapshot key" do
      let(:entity_class) { DummyEntityWithSnapshotKey }

      it "should store the snapshot key" do
        subject
        saved_entity[:snapshot_key].should == entity.class.entity_store_snapshot_key
      end
    end
  end
end
