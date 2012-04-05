require "spec_helper"

class DummyEntityValue
  include EntityValue
  define_attributes :name, :home
end

class NestedEntityValue
  include EntityValue
  define_attributes :street, :town
end

describe EntityValue do
  before(:each) do
    @name = random_string
    @home = random_string
  end
  describe "#initialize" do
    before(:each) do
      @value = DummyEntityValue.new(:name => @name, :home => @home)
    end
    it "sets the name" do
      @value.name.should eq(@name)
    end
    it "sets the home" do
      @value.home.should eq(@home)
    end
  end
  
  describe "#attributes" do
    before(:each) do
      @value = DummyEntityValue.new(:name => @name, :home => @home)
    end
    it "should return hash of attributes" do
      @value.attributes.should eq({:name => @name, :home => @home})
    end
    context "nested attributes" do
      before(:each) do
        @street = random_string
        @town = random_string
        @value.home = NestedEntityValue.new(:street => @street, :town => @town)
      end
      it "should return a hash containing the nested attribute" do
        @value.attributes.should eq({:name => @name, :home => {:street => @street, :town => @town}})
      end
    end
    
  end
end