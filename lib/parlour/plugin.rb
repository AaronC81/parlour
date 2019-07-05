# typed: true
module Parlour
  # The base class for user-defined RBI generation plugins.
  # @abstract
  class Plugin
    extend T::Sig
    extend T::Helpers
    abstract!

    @@registered_plugins = {}

    sig { returns(T::Hash[String, Plugin]) }
    # Returns all registered plugins, as a hash of their paths to the {Plugin}
    # instances themselves.
    def self.registered_plugins
      @@registered_plugins
    end

    sig { params(new_plugin: T.class_of(Plugin)).void }
    # Called automatically by the Ruby interpreter when {Plugin} is subclassed.
    # This registers the new subclass into {registered_plugins}.
    # @param new_plugin The new plugin.
    def self.inherited(new_plugin)
      registered_plugins[T.must(new_plugin.name)] = new_plugin.new
    end

    sig { params(plugins: T::Array[Plugin], generator: RbiGenerator).void }
    # Runs an array of plugins on a given generator instance.
    # @param plugins An array of {Plugin} instances.
    # @param generator The {RbiGenerator} to run the plugins on.
    def self.run_plugins(plugins, generator)
      plugins.each do |plugin|
        generator.current_plugin = plugin
        plugin.generate(generator.root)
      end
    end

    sig { abstract.params(root: RbiGenerator::Namespace).void }
    # Plugin subclasses should redefine this method and do their RBI generation
    # inside it.
    # @abstract
    # @param root The root {RbiGenerator::Namespace}.
    def generate(root); end
  end
end