require 'active_form'
module RestfulWorkflow
  module DSL
    def self.extended(base)
      base.class_inheritable_accessor :workflow_active
      base.workflow_active = false
    end

    def stage
      raise ArgumentError, "Block required!" unless block_given?
      raise "Workflow already defined for this controller!" if workflow_active
      class_inheritable_accessor :steps
      self.steps = []
      extend SingletonMethods
      include Actions
      include Filters
      include Callbacks
      yield Stage.new(self)
      self.workflow_active = true
      self
    end
  end

  module SingletonMethods
    def find_step(name)
      self.steps.find { |s| s.name == name }
    end
  end

  module Filters
    def self.included(base)
      base.prepend_before_filter :load_step
    end

    def load_step
      @step = self.class.find_step(params[:id])
    end
  end

  module Actions
    def index
      redirect_to :action => "show", :id => self.class.steps.first.name
    end
    
    def show
      before :show
      @current_object = @step.load_data(self)
      after :show
      render :action => @step.name
    end

    def update
      before :update
      @current_object = @step.data.new(params[:current_object])
      @current_object.controller = self if @current_object.respond_to?(:controller)
      after :update
      if @current_object.valid?
        redirect_to @step.go_forward(self)
      else
        before :show
        render :action => @step.name
        after :show
      end
    end
  end

  module Callbacks
    def before(cb)
      block = @step.before(cb)
      instance_eval &block if block
    end

    def after(cb)
      block = @step.after(cb)
      instance_eval &block if block
    end
  end

  class Stage
    attr_accessor :controller
    def initialize(controller)
      @controller = controller
    end

    def method_missing(method, *args, &block)
      step = Step.new(method.to_s, self, *args)
      controller.steps << step
      step.instance_eval(&block) if block_given?
      step
    end
  end

  class Step
    attr_accessor :stage, :name
    def initialize(name, stage, *args)
      @name = name
      @stage = stage
      @before_callbacks = {}
      @after_callbacks = {}
      initialize_data_class
    end
    
    def controller_class
      stage.controller
    end

    def before(symbol, &block)
      if block_given?
        @before_callbacks[symbol.to_sym] = block
      end
      @before_callbacks[symbol.to_sym]
    end

    def after(symbol, &block)
      if block_given?
        @after_callbacks[symbol.to_sym] = block
      end
      @after_callbacks[symbol.to_sym]
    end

    def data(value=nil, &block)
      if value
        @data = value
      elsif block_given?
        initialize_data_class
        @data.class_eval(&block)
      end
      @data
    end

    def completed?(controller)
      controller.session[controller.controller_name][name] rescue nil
    end

    def load_data(controller)
      if attributes = completed?(controller)
        @data.new(attributes)
      else
        @data.new
      end
    end

    def forward(value=nil, &block)
      raise ArgumentError, "Value or block required" unless value || block_given?
      @forward = if value
        case value
        when Symbol
          { :id => value.to_s }
        else
          value
        end
      else
        block
      end
    end

    def go_forward(controller)
      if @forward
        @forward.respond_to?(:call) ? controller.instance_eval(&@forward) : @forward
      else
        { :id => (next_step || self).name } 
      end
    end

    def back(value=nil, &block)
      raise ArgumentError, "Value or block required" unless value || block_given?
      @back = if value
        case value
        when Symbol
          { :id => value.to_s }
        else
          value
        end
      else
        block
      end
    end

    def go_back(controller)
      if @back
        @back.respond_to?(:call) ? controller.instance_eval(&@back) : @back
      else
        { :id => (previous_step || self).name }
      end
    end

    def first?
      controller_class.steps.first == self
    end

    def last?
      controller_class.steps.last == self
    end
    
    def method_missing(method, *args, &block)
      case method.to_s
      when /^before_/
        before method.to_s.sub(/^before_/, ''), &block
      when /^after_/
        after method.to_s.sub(/^after_/, ''), &block
      else
        super
      end
    end
    
    private
    def initialize_data_class
      @data = Class.new(ActiveForm)
      @data.class_eval %Q{
        attr_accessor :controller
        def save
          returning super do |valid|
            if valid
              controller.session[controller.controller_name] ||= {}
              controller.session[controller.controller_name][#{name}.intern] = self.attributes
            end
          end
        end
      }
    end

    def next_step
      unless last?
        controller_class.steps[controller_class.steps.index(self) + 1]
      end
    end
    
    def previous_step
      unless first?
        controller_class.steps[controller_class.steps.index(self) - 1]
      end
    end
    
  end
end
