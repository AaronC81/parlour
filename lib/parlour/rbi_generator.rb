# typed: true
module Parlour
  # The RBI generator.
  class RbiGenerator
    extend T::Sig

    sig { params(break_params: Integer, tab_size: Integer).void }
    # Creates a new RBI generator.
    #
    # @param break_params If there are at least this many parameters in a 
    #   Sorbet `sig`, then it is broken onto separate lines.
    # @param tab_size The number of spaces to use per indent.
    def initialize(break_params: 4, tab_size: 2)
      @options = Options.new(break_params: break_params, tab_size: tab_size)
      @root = Namespace.new(self)
    end

    sig { returns(Options) }
    # The formatting options for this generator.
    attr_reader :options

    sig { returns(Namespace) }
    # The root {Namespace} of this generator.
    attr_reader :root

    sig { returns(T.nilable(Plugin)) }
    # The plugin which is currently generating new definitions.
    # {Plugin#run_plugins} controls this value.
    attr_accessor :current_plugin

    sig { returns(String) }
    # Returns the complete contents of the generated RBI file as a string.
    #
    # @return [String] The generated RBI file
    def rbi
      root.generate_rbi(0, options).join("\n")
    end
  end
end
