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
      attr_reader :current_object
      helper ::RestfulWorkflow::Helpers
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

  module Helpers
    def link_forward(contents)
      link_to contents, @step.forward_url
    end
    
    def link_back(contents)
      link_to contents, @step.back_url
    end
    
    def each_step(&block)
      @controller.class.steps.each {|step|
        step.controller = @controller
        yield step
      }
    end
  end

  module Filters
    def self.included(base)
      base.prepend_before_filter :load_current_object, :only => [:show, :update]
      base.prepend_before_filter :init_data, :only => [:show, :update]
      base.prepend_before_filter :load_step, :only => [:show, :update]
      base.prepend_before_filter :init_steps
    end

    def load_step
      @step = self.class.find_step(params[:id])
      if @step.blank?
        redirect_to :action => "show", :id => self.class.steps.first.name
      end
    end
    
    def init_steps
      self.class.steps.each {|s| s.controller = self }
    end

    def init_data
      @step.eval_deferred_data_class
    end
    
    def load_current_object
      case action_name
      when 'show'
        @current_object = @step.load_data
      when 'update'
        @current_object = @step.data.new(params[:current_object])
      end
      @current_object.controller = self if @current_object.respond_to?(:controller)
    end
    
  end

  module Actions
    def index
      first_uncompleted_step = self.class.steps.find {|step| !step.completed? }
      redirect_to :action => "show", :id => (first_uncompleted_step || self.class.steps.first).name
    end
    
    def show
      @step.data_block
      before :show
      render :action => @step.view
    end

    def update
      before :update
      if @current_object.save
        redirect_to @step.forward_url
      else
        before :show
        render :action => @step.view
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
    attr_accessor :controller_class
    def initialize(controller_class)
      @controller_class = controller_class
    end

    def method_missing(method, *args, &block)
      step = Step.new(method.to_s, self, *args)
      controller_class.steps << step
      step.instance_eval(&block) if block_given?
      step
    end
  end

  class Step
    attr_accessor :stage, :name, :controller, :long_name, :view, :in_menu, :data_block
    def initialize(name, stage, *args)
      @name = name
      @view = name
      @stage = stage
      @in_menu = true
      @before_callbacks = {}
      @after_callbacks = {}
      initialize_data_class
    end
    
    def long_name(new_val=nil)
      @long_name = new_val if new_val
      @long_name
    end
    
    def view(new_val=nil)
      @view = new_val if new_val
      @view
    end

    def in_menu(new_val=nil)
      @in_menu = new_val unless new_val.nil?
      @in_menu
    end
    
    def in_menu?
      @in_menu
    end

    def controller_class
      stage.controller_class
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

    def data(*args, &block)
      options = args.extract_options!
      if args.first
        @data = args.first
      elsif block_given?
        initialize_data_class 
        unless options[:defer]
          @data.class_eval(&block)
        else
          @data_block = block
        end
      end
      @data
    end

    def completed?
      # controller.session[controller.controller_name][name] rescue nil
      load_data.valid?
    end

    def load_data
      #  !@data_block && 
      if attributes = controller.session[controller.controller_name][name] rescue nil
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

    def forward_url
      if @forward
        url = @forward.respond_to?(:call) ? controller.instance_eval(&@forward) : @forward
        url = { :id => url } if url.kind_of?(Symbol)
      end
      url || { :id => (next_step || self).name } 
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

    def back_url
      if @back
        url = @back.respond_to?(:call) ? controller.instance_eval(&@back) : @back
        url = { :id => url } if url.kind_of?(Symbol)
      end
      url || { :id => (previous_step || self).name }
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
    
    def eval_deferred_data_class
      if data_block
        initialize_data_class
        data.controller = controller if data.respond_to?(:controller)
        data.class_eval(&data_block) 
      end
    end
    
    private

    def initialize_data_class
      @data = Class.new(ActiveForm)
      @data.class_eval %Q{
        cattr_accessor :controller
        def save
          returning super do |valid|
            if valid
              # No Session store for now
              # controller.session[controller.controller_name] ||= {}
              # controller.session[controller.controller_name]['#{name}'] = self.attributes
            end
          end
        end
      }, __FILE__, __LINE__
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
