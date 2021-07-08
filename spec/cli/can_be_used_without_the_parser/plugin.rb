require 'parlour'

class Plugin < Parlour::Plugin
  def initialize(options)
    @class_name = options[:class_name]
  end

  def generate(root)
    root.create_module('C') do |c|
      c.create_class(@class_name)
    end
  end

  def strictness
    "strong"
  end
end
