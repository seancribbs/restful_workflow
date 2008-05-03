require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow::Filters" do
  before :each do
    @kontroller = Class.new(ActionController::Base)
    @kontroller.stage do |steps| @steps = steps end
    @step_one = @steps.one
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
  
  it "should add a before filter to initialize all steps with the current controller" do
    @kontroller.filter_chain.should_not be_empty
    @kontroller.find_filter(:init_steps).should_not be_nil
    @kontroller.find_filter(:init_steps).should be_before
  end
  
  it "should initialize all steps with the current controller in the before filter" do
    @controller = @kontroller.new
    @controller.init_steps
    @step_one.controller.should == @controller
  end
  
  it "should load the current object in the before filter" do
    @controller = @kontroller.new
    @data = mock('object')
    @controller.should_receive(:params).and_return({:id => "one"})
    @controller.should_receive(:action_name).and_return("show")
    @step_one.should_receive(:load_data).and_return(@data)
    @controller.init_steps
    @controller.load_step
    @controller.load_current_object
    @controller.send(:instance_variable_get, "@current_object").should == @data
  end
  
  it "should add a before filter to load the current object" do
    @kontroller.filter_chain.should_not be_empty
    @kontroller.find_filter(:load_current_object).should_not be_nil
    @kontroller.find_filter(:load_current_object).should be_before
  end
end