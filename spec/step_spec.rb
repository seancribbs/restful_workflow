require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow::Step" do
  before :each do
    @kontroller = Class.new(ActionController::Base)
    @kontroller.stage {|steps| @stage = steps }
    @step = @one = @stage.one
  end
  
  it "should have a reference to its stage" do
    @step.stage.should == @stage
  end
  
  it "should have a reference to the stage's controller" do
    @step.controller_class.should == @kontroller
  end
  
  it "should accept blocks for before callbacks" do
    @step.before(:update).should be_nil
    @step.before(:update) { "blah" }
    @step.before(:update).should be_kind_of(Proc)
  end
  
  it "should accept blocks for after callbacks" do
    @step.after(:update).should be_nil
    @step.after(:update) { "blah" }
    @step.after(:update).should be_kind_of(Proc)
  end
  
  it "should accept a class as its data type" do
    class Foo; end
    @step.data Foo
    @step.data.should == Foo
  end
  
  it "should accept a block and define an anonymous data type" do
    @step.data do
      column :name, :type => :string
    end
    @step.data.should be_kind_of(ActiveForm)
    @step.data.new.should respond_to(:name)
  end
  
  describe "interacting with the session" do
    before :each do
      @controller = @kontroller.new
      class << @controller
        def controller_name
          "foo"
        end
      end
      @step.data do
        column :first_name, :type => :string
      end
    end

    it "should not be complete if its data does not exist in the session" do
      @controller.should_receive(:session).and_return({})
      @step.should_not be_complete(@controller)
    end

    it "should be complete if its data exists in the session" do
      @controller.should_receive(:session).and_return({'foo' => {'one' => "data"}})
      @step.should be_complete(@controller)
    end

    it "should load its data from the session" do
      @controller.should_receive(:session).and_return({'foo' => {'one' => {'first_name' => 'Sean'}}})
      @step.load_data(@controller).first_name.should == 'Sean'
    end
  end
  
  describe "in a series of steps" do
    before :each do
      @two = @stage.two
      @three = @stage.three
    end
    
    it "should determine whether it is first" do
      @one.should be_first
      @two.should_not be_first
      @three.should_not be_first
    end
    
    it "should determine whether it is last" do
      @three.should be_last
      @one.should_not be_last
      @two.should_not be_last
    end
    
    it "should determine the default next step" do
      @one.next_step.should == @two
      @two.next_step.should == @three
    end
    
    it "should determine the default previous step" do
      @two.previous_step.should == @one
      @three.previous_step.should == @two
    end
    
    it "should determine the next step's URL" do
      @one.go_forward(@controller).should == {:id => "two"}
      @two.go_forward(@controller).should == {:id => "three"}
    end
    
    it "should determine the previous step's URL" do
      @two.go_back(@controller).should == {:id => "one"}
      @three.go_back(@controller).should == {:id => "three"}
    end
    
    describe "when first" do
      it "should have a nil default previous step" do
        @one.previous_step.should be_nil
      end
      
      it "should determine the previous step's URL to be its own" do
        @one.go_back(@controller).should == {:id => "one"}
      end
    end
    
    describe "when last" do
      it "should have a nil default next step" do
        @three.next_step.should be_nil
      end
      
      it "should determine the next step's URL to be its own" do
        @three.go_forward(@controller).should == { :id => "three" }
      end
    end
    
    describe "when the next step is assigned manually" do
      it "to a symbol should determine the next step's URL by name" do
        @one.forward :three
        @one.go_forward(@controller).should == {:id => "three"}
      end
      
      it "to a block should evaluate the block in the context of the controller to determine the next step's URL" do
        @one.forward do
          :controller => controller_name, :id => "five"
        end
        @one.go_forward(@controller).should == {:controller => "foo", :id => "five"}
      end
    end
  end
  
end