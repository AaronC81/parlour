require 'parlour'

module FooBar
  class Plugin < Parlour::Plugin
    def generate(root)
      root.create_module(name: 'Foo') do |foo|
        foo.add_comment('This is an example plugin!')
        foo.create_module(name: 'Bar')
        foo.create_module(name: 'Bar', interface: true)
      end
    end
  end
end