# typed: true
module Parlour
  class RbsGenerator < Generator
    # Represents a module definition.
    class ModuleNamespace < Namespace
      extend T::Sig

      Child = type_member {{ fixed: RbsObject }}

      sig do
        params(
          generator: Generator,
          name: T.nilable(String),
          type_parameters: T::Array[Symbol],
          block: T.nilable(T.proc.params(x: ModuleNamespace).void)
        ).void
      end
      # Creates a new module definition.
      # @note You should use {Namespace#create_module} rather than this directly.
      #
      # @param generator [RbsGenerator] The current RbsGenerator.
      # @param name [String, nil] The name of this module.
      # @param type_parameters [Array<Symbol>] This module's type parameters, e.g. +[:T]+
      #   for +module Foo[T]+.
      # @param block A block which the new instance yields itself to.
      # @return [void]
      def initialize(generator, name = nil, type_parameters: [], &block)
        super(generator, name, &T.cast(block, T.nilable(T.proc.params(x: Namespace).void)))
        @type_parameters = type_parameters
      end

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBS lines for this module.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBS lines, formatted as specified.
      def generate_rbs(indent_level, options)
        type_parameters_definition = type_parameters.any? ? "[#{type_parameters.join(', ')}]" : ''

        lines = generate_comments(indent_level, options)
        lines << options.indented(indent_level, "module #{name}#{type_parameters_definition}")
        lines += generate_body(indent_level + 1, options)
        lines << options.indented(indent_level, "end")
      end

      sig { returns(T::Array[Symbol]) }
      # This module's type parameters.
      # @return [Array<Symbol>]
      attr_reader :type_parameters

      sig { override.returns(T::Array[T.any(Symbol, T::Hash[Symbol, String])]) }
      def describe_attrs
        (type_parameters.any? ? [:type_parameters] : []) + [:children]
      end
    end
  end
end
