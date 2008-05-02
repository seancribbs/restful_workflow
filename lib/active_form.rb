# = ActiveForm - non persistent ActiveRecord
#
# Simple base class to make AR objects without a corresponding database
# table.  These objects can still use AR validations but can't be saved
# to the database.
#
# == Example
#
#   class FeedbackForm < ActiveForm
#     column :email
#     column :message, :type => :text
#     validates_presence_of :email, :message
#   end
#
class ActiveForm < ActiveRecord::Base
  def self.columns # :nodoc:
    @columns ||= []
  end

  # Define an attribute.  It takes the following options:
  # [+:type+] schema type
  # [+:default+] default value
  # [+:null+] whether it is nullable
  # [+:human_name+] human readable name
  def self.column(name, options = {})
    name = name.to_s
    options.each { |k,v| options[k] = v.to_s if Symbol === v }
    
    if human_name = options.delete(:human_name)
      name.instance_variable_set('@human_name', human_name)
      def name.humanize; @human_name; end
    end
    
    columns << ActiveRecord::ConnectionAdapters::Column.new(
      name,
      options.delete(:default),
      options.delete(:type),
      options.include?(:null) ? options.delete(:null) : true
    )
    
    raise ArgumentError.new("unknown option(s) #{options.inspect}") unless options.empty?
  end

  def self.abstract_class # :nodoc:
    true
  end
  
  def save # :nodoc:
    valid?
  end
end
