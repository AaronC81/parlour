# typed: true
module Parlour
  class Generator
    extend T::Sig
  
    sig { params(break_params: Integer, tab_size: Integer, sort_namespaces: T::Boolean).void }
    # Creates a new generator.
    #
    # @param break_params [Integer] If there are at least this many parameters in a 
    #   signature, then it is broken onto separate lines.
    # @param tab_size [Integer] The number of spaces to use per indent.
    # @param sort_namespaces [Boolean] Whether to sort all items within a
    #   namespace alphabetically.
    # @return [void]
    def initialize(break_params: 4, tab_size: 2, sort_namespaces: false)
      @options = RbiGenerator::Options.new(
        break_params: break_params,
        tab_size: tab_size,
        sort_namespaces: sort_namespaces
      )
      @root = RbiGenerator::Namespace.new(self)
    end

    sig { overridable.returns(RbiGenerator::Options) }
    # The formatting options for this generator. Currently ignored.
    # @return [Options]
    attr_reader :options

    sig { overridable.returns(RbiGenerator::Namespace) }
    # The root {Namespace} of this generator.
    # @return [Namespace]
    attr_reader :root
  end
end