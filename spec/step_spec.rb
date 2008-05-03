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
  
  it "should have a name" do
    @one.name.should == "one"
  end
  
  it "should have a long_name accessor" do
    @one.should respond_to(:long_name)
    @one.should respond_to(:long_name=)
    @one.long_name.should be_nil
    @one.long_name "Test step"
    @one.long_name.should == "Test step"
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
  
  it "should have a default data type" do
    @step.data.should_not be_nil
    @step.data.should be_kind_of(Class)
    @step.data.superclass.should == ActiveForm
    @step.data.instance_methods.should include("controller")
    @step.data.instance_methods.should include("controller=")
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
    @step.data.superclass.should == ActiveForm
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
      @step.controller = @controller
    end

    it "should not be complete if its data does not exist in the session" do
      @controller.should_receive(:session).and_return({})
      @step.should_not be_completed
    end

    it "should be complete if its data exists in the session" do
      @controller.should_receive(:session).and_return({'foo' => {'one' => "data"}})
      @step.should be_completed
    end

    it "should load its data from the session" do
      @controller.should_receive(:session).and_return({'foo' => {'one' => {'first_name' => 'Sean'}}})
      @step.load_data.first_name.should == 'Sean'
    end
  end
  
  describe "in a series of steps" do
    before :each do
      @controller = @kontroller.new
      class << @controller
        def controller_name
          "foo"
        end
      end
      @two = @stage.two
      @three = @stage.three
      [@one, @two, @three].each {|s| s.controller = @controller }
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
      @one.send(:next_step).should == @two
      @two.send(:next_step).should == @three
    end
    
    it "should determine the default previous step" do
      @two.send(:previous_step).should == @one
      @three.send(:previous_step).should == @two
    end
    
    it "should determine the next step's URL" do
      @one.forward_url.should == {:id => "two"}
      @two.forward_url.should == {:id => "three"}
    end
    
    it "should determine the previous step's URL" do
      @two.back_url.should == {:id => "one"}
      @three.back_url.should == {:id => "two"}
    end
    
    describe "when first" do
      it "should have a nil default previous step" do
        @one.send(:previous_step).should be_nil
      end
      
      it "should determine the previous step's URL to be its own" do
        @one.back_url.should == {:id => "one"}
      end
    end
    
    describe "when last" do
      it "should have a nil default next step" do
        @three.send(:next_step).should be_nil
      end
      
      it "should determine the next step's URL to be its own" do
        @three.forward_url.should == { :id => "three" }
      end
    end
    
    describe "when the next step is assigned manually" do
      it "to a symbol should determine the next step's URL by name" do
        @one.forward :three
        @one.forward_url.should == {:id => "three"}
      end
      
      it "to a block should evaluate the block in the context of the controller to determine the next step's URL" do
        @one.forward do
          { :controller => controller_name, :id => "five" }
        end
        @one.forward_url.should == {:controller => "foo", :id => "five"}
      end
      
      it "to something other than a block or symbol should determine the next step's URL" do
        @one.forward "/"
        @one.forward_url.should == "/"
      end
    end
    
    describe "when the previous step is assigned manually" do
      it "to a symbol should determine the previous step's URL by name" do
        @one.back :three
        @one.back_url.should == {:id => "three"}
      end
      
      it "to a block should evaluate the block in the context of the controller to determine the previous step's URL" do
        @one.back do
          {:controller => controller_name, :id => "five"}
        end
        @one.back_url.should == {:controller => "foo", :id => "five"}
      end
      
      it "to something other than a block or symbol should determine the previous step's URL" do
        @one.back "/"
        @one.back_url.should == "/"
      end
    end
  end
  
end