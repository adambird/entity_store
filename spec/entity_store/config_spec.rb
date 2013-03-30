require 'spec_helper'

module Level1
  module Level2
    class MyClass
    end
    class AnotherClass
    end
  end
end

describe EntityStore::Config do

  describe "load_type" do
    
    subject { EntityStore::Config.load_type('Level1::Level2::MyClass') }
    
    it "should be an Level1::Level2::MyClass" do
      subject.should eq(Level1::Level2::MyClass)
    end

    context "when type_loader set" do
      before(:each) do
        EntityStore::Config.type_loader = lambda { |type_name|
          Level1::Level2::AnotherClass
        }
      end

      it "should return the result of that type loader" do
        subject.should eq(Level1::Level2::AnotherClass)
      end

      after(:each) do
        EntityStore::Config.type_loader = nil
      end
    end
  end
end
