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

    sig { abstract.params(root: RbiGenerator::Namespace).void }
    def generate(root); end
  end
end