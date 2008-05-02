require File.dirname(__FILE__) + "/spec_helper"

describe "RestfulWorkflow plugin" do
  it "should extend ActionController with the DSL" do
    (class << ActionController::Base; self; end).included_modules.should include(RestfulWorkflow::DSL)
  end
end