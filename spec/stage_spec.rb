require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow::Stage" do
  before :each do
    @kontroller = Class.new(ActionController::Base)
    @kontroller.stage {|stage|}
    @stage = RestfulWorkflow::Stage.new(@kontroller)
  end
  
  it "should have a reference to the controller class" do
    @stage.controller.should == @kontroller
  end
  
  describe "creating steps" do
    before :each do
      @one = @stage.one
      @two = @stage.two
    end

    it "should add the steps to the controller's collection" do
      @kontroller.steps.should == [@one, @two]
    end
    
    it "should evaluate the passed block in the context of the step" do
      @stage.three do
        self.name = "Three"
      end
      @kontroller.steps.last.name.should == "Three"
    end
  end
end