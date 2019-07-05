# typed: true
module Parlour
  class Plugin
    extend T::Sig
    extend T::Helpers
    abstract!

    @@registered_plugins = []

    sig { returns(T::Array[Plugin]) }
    def self.registered_plugins
      @@registered_plugins
    end

    sig { params(new_plugin: Plugin).void }
    def self.inherited(new_plugin)
      registered_plugins << new_plugin
    end

    sig { params(generator: RbiGenerator).void }
    def self.run_all_plugins(generator)
      registered_plugins.each do |plugin|
        generator.current_plugin = plugin
        plugin.generate(generator.root)
      end
    end

    sig { abstract.params(root: RbiGenerator::Namespace).void }
    def generate(root); end
  end
end