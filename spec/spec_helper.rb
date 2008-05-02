$: << File.dirname(__FILE__) + '/../lib'
require 'rubygems'
gem 'rspec', ">=1.1.0"
%w[spec action_pack active_record active_form restful_workflow
   action_controller action_controller/test_process action_controller/integration
   rspec_on_rails/redirect_to rspec_on_rails/render_template].each &method(:require)
require File.dirname(__FILE__) + '/../init'
