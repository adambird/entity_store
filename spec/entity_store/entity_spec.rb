require "spec_helper"

class ThingEntityValue
  include EntityValue

  attr_accessor :name
end

class DummyEntity
  include Entity

  related_entities :club, :user

  attr_accessor :name, :description, :members
  entity_value_array_attribute :things, ThingEntityValue
end

describe Entity do
  describe ".related_entities" do
    before(:each) do
      @entity_loader = double(Store)
      @club = double('Entity', :id => random_string)
      @user = double('Entity', :id => random_string)
      @entity = DummyEntity.new(:related_entity_loader => @entity_loader, :club_id => @club.id, :user_id => @user.id)
      @entity_loader.stub(:get) { |id| 
        case id
        when @club.id
          @club 
        when @user.id
          @user
        end
      }
    end

    it "should have the club_id set" do
      @entity.club_id.should eq(@club.id)
    end
    it "should load club" do
      @entity.club.should eq(@club)
    end
    it "should call entity_loader with club id" do
      @entity_loader.should_receive(:get).with(@club.id)
      @entity.club
    end
    it "should have the user_id set" do
      @entity.user_id.should eq(@user.id)
    end
    it "should load user" do
      @entity.user.should eq(@user)
    end
    it "should call entity_loader with user id" do
      @entity_loader.should_receive(:get).with(@user.id)
      @entity.user
    end

    context "when only user loaded" do
      before(:each) do
        @entity.user
      end

      it "should only have user in the loaded related entities collection" do
        @entity.loaded_related_entities.should eq([@user])
      end
    end

    context "when both user and club loaded" do
      before(:each) do
        @entity.club
        @entity.user
      end

      it "should only have user in the loaded related entities collection" do
        @entity.loaded_related_entities.should eq([@club, @user])
      end
    end
  end

  describe "#attributes" do
    before(:each) do
      @entity = DummyEntity.new(:id => @id = random_object_id, :club_id => @club_id = random_string, 
        :user_id => @user_id = random_string, :name => @name = random_string, :version => @version = random_integer,
        :members => [])
    end

    subject { @entity.attributes }

    it "returns a hash of the attributes" do
      subject.should eq({
        :id => @id, :version => @version, :name => @name, :club_id => @club_id, 
        :user_id => @user_id, :description => nil, :members => [], :things => []
        })
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

end