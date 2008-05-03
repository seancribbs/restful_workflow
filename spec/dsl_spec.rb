require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow::DSL" do
  it "should add a 'stage' method to ActionController" do
    ActionController::Base.should respond_to(:stage)
  end
  
  it "should add a 'workflow_active' property to ActionController" do
    ActionController::Base.should respond_to(:workflow_active)
    ActionController::Base.should respond_to(:workflow_active=)
  end
  
  describe "#stage" do
    before :each do
      @klass = Class.new(ActionController::Base)
    end

    it "should require a block" do
      lambda { @klass.stage }.should raise_error
    end
    
    it "should yield a Stage object" do
      @klass.stage {|steps| steps.should be_kind_of(RestfulWorkflow::Stage) }
    end
    
    describe "after definition" do
      before :each do
        @klass.stage {|steps|}
      end
      
      it "should allow only one definition" do
        lambda { @klass.stage {|steps|}}.should raise_error
      end
        
      it "should add a steps accessor" do
        @klass.should respond_to(:steps)
        @klass.steps.should == []
      end
    
      it "should extend the controller with singleton methods" do
        (class << @klass; self; end).included_modules.should include(RestfulWorkflow::SingletonMethods)
      end
    
      it "should include filters" do
        @klass.included_modules.should include(RestfulWorkflow::Filters)
      end
      
      it "should include actions" do
        @klass.included_modules.should include(RestfulWorkflow::Actions)
      end
      
      it "should include callbacks" do
        @klass.included_modules.should include(RestfulWorkflow::Callbacks)
      end
      
      it "should add a current_object accessor" do
        @klass.new.should respond_to(:current_object)
      end
    end
  end
end