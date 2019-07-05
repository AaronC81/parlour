require 'parlour'

module FooBar
  class Plugin < Parlour::Plugin
    def generate(root)
      root.create_module('Foo') do |foo|
        foo.add_comment('This is an example plugin!')
        foo.create_module('Bar')
      end
    end
  end
end