require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow::SingletonMethods" do
  before :each do
    @klass = Class.new(ActionController::Base)
    @klass.stage do |steps|
      steps.one
      steps.two
      steps.three
    end
  end
  
  it "should find a step in the controller's collection" do
    @klass.find_step('one').name.should == 'one'
  end
end