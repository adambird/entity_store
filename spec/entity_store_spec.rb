require 'spec_helper'

module Level1
  module Level2
    class MyClass
    end
    class AnotherClass
    end
  end
end

describe EntityStore do

  describe "load_type" do
    
    subject { EntityStore.load_type('Level1::Level2::MyClass') }
    
    it "should be an Level1::Level2::MyClass" do
      subject.should eq(Level1::Level2::MyClass)
    end

    context "when type_loader set" do
      before(:each) do
        EntityStore.type_loader = lambda { |type_name|
          Level1::Level2::AnotherClass
        }
      end

      it "should return the result of that type loader" do
        subject.should eq(Level1::Level2::AnotherClass)
      end
    end
  end
end
