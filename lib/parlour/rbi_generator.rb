# typed: true
module Parlour
  class RbiGenerator
    extend T::Sig

    sig { params(break_params: Integer, tab_size: Integer).void }
    def initialize(break_params: 4, tab_size: 2)
      @options = Options.new(break_params: break_params, tab_size: tab_size)
      @root = Namespace.new(self)
    end

    sig { returns(Options) }
    attr_reader :options

    sig { returns(Namespace) }
    attr_reader :root

    sig { returns(T.nilable(Plugin)) }
    attr_accessor :current_plugin

    sig { returns(String) }
    def rbi
      root.generate_rbi(0, options).join("\n")
    end
  end
end