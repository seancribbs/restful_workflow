require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow::Filters" do
  before :each do
    @kontroller = Class.new(ActionController::Base)
    @kontroller.stage do |steps|
      @step_one = steps.one
    end
  end
  
  it "should add a before filter to load the current step" do
    @kontroller.filter_chain.should_not be_empty
    @kontroller.find_filter(:load_step).should_not be_nil
    @kontroller.find_filter(:load_step).should be_before
  end

  it "should load the current step in the before filter" do
    @controller = @kontroller.new
    @controller.should_receive(:params).and_return({:id => "one"})
    @controller.load_step.should == @step_one
  end
end