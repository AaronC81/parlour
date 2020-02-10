# typed: true
module Parlour
  # The RBI generator.
  class RbiGenerator
    extend T::Sig

    sig { params(break_params: Integer, tab_size: Integer, sort_namespaces: T::Boolean).void }
    # Creates a new RBI generator.
    #
    # @example Create a default generator.
    #   generator = Parlour::RbiGenerator.new
    # 
    # @example Create a generator with a custom +tab_size+ of 3.
    #   generator = Parlour::RbiGenerator.new(tab_size: 3)
    #
    # @param break_params [Integer] If there are at least this many parameters in a 
    #   Sorbet +sig+, then it is broken onto separate lines.
    # @param tab_size [Integer] The number of spaces to use per indent.
    # @param sort_namespaces [Boolean] Whether to sort all items within a
    #   namespace alphabetically.
    # @return [void]
    def initialize(break_params: 4, tab_size: 2, sort_namespaces: false)
      @options = Options.new(
        break_params: break_params,
        tab_size: tab_size,
        sort_namespaces: sort_namespaces
      )
      @root = Namespace.new(self)
    end

    sig { overridable.returns(Options) }
    # The formatting options for this generator.
    # @return [Options]
    attr_reader :options

    sig { overridable.returns(Namespace) }
    # The root {Namespace} of this generator.
    # @return [Namespace]
    attr_reader :root

    sig { overridable.returns(T.nilable(Plugin)) }
    # The plugin which is currently generating new definitions.
    # {Plugin#run_plugins} controls this value.
    # @return [Plugin, nil]
    attr_accessor :current_plugin

    sig { overridable.params(strictness: String).returns(String) }
    # Returns the complete contents of the generated RBI file as a string.
    #
    # @return [String] The generated RBI file
    def rbi(strictness = 'strong')
      "# typed: #{strictness}\n" + root.generate_rbi(0, options).join("\n") + "\n"
    end
  end
end
