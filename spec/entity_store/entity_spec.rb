require "spec_helper"

class ThingEntityValue
  include EntityValue

  attr_accessor :name
end

class DummyEntity
  include Entity

  attr_accessor :name, :description, :members
  entity_value_array_attribute :things, ThingEntityValue
  entity_value_dictionary_attribute :other_things, ThingEntityValue
end

describe Entity do

  describe "#attributes" do
    before(:each) do
      @entity = DummyEntity.new(:id => @id = random_object_id, :club_id => @club_id = random_string,
        :user_id => @user_id = random_string, :name => @name = random_string, :version => @version = random_integer,
        :members => [], things: [ ThingEntityValue.new(name: random_string), ThingEntityValue.new(name: random_string) ],
        other_things_dictionary: { random_string => ThingEntityValue.new(name: random_string) } )
    end

    subject { @entity.attributes }

    it "returns a hash of the attributes" do
      subject.should eq({
        :id => @id, :version => @version, :name => @name, :description => nil, :members => [],
        :things => @entity.things.map { |t| { name: t.name } },
        :other_things_dictionary => { @entity.other_things_dictionary.keys.first => { name: @entity.other_things_dictionary.values.first.name }}
        })
    end
    context "when initialise with attributes" do

      subject { DummyEntity.new(@entity.attributes) }

      it "should set simple attributes" do
        subject.id.should eq(@entity.id)
      end
      it "should set entity value array attributes" do
        actual = subject
        actual.things.count.should eq(@entity.things.count)
        actual.things.each_with_index do |item, i|
          item.should eq(@entity.things[i])
        end
      end
      it "should set entity value dictionary attributes" do
        actual = subject
        actual.other_things_dictionary.keys.count.should eq(@entity.other_things_dictionary.keys.count)
        actual.other_things_dictionary.each_pair do |k,v|
          v.should eq(@entity.other_things_dictionary[k])
        end
      end
    end

    context "when initialize with entity" do
      subject { DummyEntity.new(@entity) }

      it "should set simple attributes" do
        subject.id.should eq(@entity.id)
      end

      it "should set entity value array attributes" do
        actual = subject
        actual.things.count.should eq(@entity.things.count)
        actual.things.each_with_index do |item, i|
          item.should eq(@entity.things[i])
        end
      end

      it "should set entity value dictionary attributes" do
        actual = subject
        actual.other_things_dictionary.keys.count.should eq(@entity.other_things_dictionary.keys.count)
        actual.other_things_dictionary.each_pair do |k,v|
          v.should eq(@entity.other_things_dictionary[k])
        end
      end
    end

    context "when initialize with something unknown" do
      subject { DummyEntity.new(1) }

      it "should raise a readable error" do
        expect { subject }.to raise_error(RuntimeError, /\ADo not know how to create DummyEntity from (Integer|Fixnum)\z/)
      end
    end
  end

  describe ".entity_value_array_attribute" do
    let(:entity) { DummyEntity.new }

    describe "setter" do
      context "with array of hashes" do
        let(:items) { [{ name: random_string }, { name: random_string }] }

        before(:each) do
          entity.things = items
        end

        it "should create the number of items" do
          entity.things.count.should eq(items.count)
        end
        it "should create an array of the correct type" do
          entity.things.each do |item| item.should be_an_instance_of(ThingEntityValue) end
        end
        it "should set the value" do
          entity.things.each_with_index do |item, i| item.name.should eq(items[i][:name]) end
        end
      end
      context "with an array of matching items" do
        let(:items) { [ ThingEntityValue.new(name: random_string), ThingEntityValue.new(name: random_string)] }

        before(:each) do
          entity.things = items
        end

        it "should create the number of items" do
          entity.things.count.should eq(items.count)
        end
        it "should set items" do
          entity.things.each_with_index do |item, i| item.should be(items[i]) end
        end
      end
      context "when something else in array" do
        let(:items) { [ random_string, random_string ] }

        it "should raise and argument error" do
          expect { entity.things = items }.to raise_error(ArgumentError)
        end
      end
      context "when already populated" do
        let(:items) { [ ThingEntityValue.new(name: random_string), ThingEntityValue.new(name: random_string)] }

        before(:each) do
          entity.things = [{ name: random_string }, { name: random_string }]
          entity.things = items
        end

        it "should replace the contents" do
          entity.things.should eq(items)
        end
      end
      context "when passed nil" do
        before(:each) do
          entity.things = nil
        end

        it "should result in an empty array" do
          entity.things.should be_empty
        end
      end
    end

    describe "getter" do
      context "when nothing set" do
        it "should return and empty array" do
          entity.things.count.should eq(0)
        end
      end
    end

    describe "hash initialisation, ie from snapshot" do
      let(:attributes) { { things: [ { name: random_string }, { name: random_string } ] } }

      subject { DummyEntity.new(attributes) }

      it "should create the number of items" do
        subject.things.count.should eq(attributes[:things].count)
      end
      it "should create an array of the correct type" do
        subject.things.each do |item| item.should be_an_instance_of(ThingEntityValue) end
      end
      it "should set the value" do
        subject.things.each_with_index do |item, i| item.name.should eq(attributes[:things][i][:name]) end
      end

    end
  end

  describe ".entity_value_dictionary_attribute" do
    let(:ids) { [ random_string, random_string ] }
    let(:entity) { DummyEntity.new }

    describe "setter" do
      context "with hashes" do
        let(:items) { { ids[0] => { name: random_string }, ids[1] => { name: random_string } } }

        before(:each) do
          entity.other_things_dictionary = items
        end

        it "should create an items of the correct type" do
          ids.each do |id| entity.other_things_dictionary[id].should be_an_instance_of(ThingEntityValue) end
        end
        it "should set the value" do
          ids.each do |id| entity.other_things_dictionary[id].name.should eq(items[id][:name]) end
        end
      end
      context "with a hash of typed " do
        let(:items) { { ids[0] => ThingEntityValue.new(name: random_string), ids[1] => ThingEntityValue.new(name: random_string) } }

        before(:each) do
          entity.other_things_dictionary = items
        end

        it "should set items" do
          ids.each do |id| entity.other_things_dictionary[id].name.should eq(items[id].name) end
        end
      end
      context "when something else in array" do
        let(:items) { { ids[0] => random_string, ids[1] => random_string } }

        it "should raise and argument error" do
          expect { entity.other_things_dictionary = items }.to raise_error(ArgumentError)
        end
      end
    end

    describe "getter" do
      context "when nothing set" do
        it "should return and empty array" do
          entity.other_things_dictionary[random_string].should be_nil
        end
      end
    end

    describe "hash initialisation, ie from snapshot" do
      let(:attributes) { { other_things_dictionary: { ids[0] => { name: random_string }, ids[1] => { name: random_string } } } }

      subject { DummyEntity.new(attributes) }

      it "should create an array of the correct type" do
        entity = subject
        ids.each do |id| entity.other_things_dictionary[id].should be_an_instance_of(ThingEntityValue) end
      end
      it "should set the value" do
        entity = subject
        ids.each do |id| entity.other_things_dictionary[id].name.should eq(attributes[:other_things_dictionary][id][:name]) end
      end
    end
  end

end
