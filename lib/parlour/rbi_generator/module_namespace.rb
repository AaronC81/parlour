# typed: true
module Parlour
  class RbiGenerator
    # Represents a module definition.
    class ModuleNamespace < Namespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          interface: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).void
      end
      # Creates a new module definition.
      # @note You should use {Namespace#create_module} rather than this directly.
      # 
      # @param generator [RbiGenerator] The current RbiGenerator.
      # @param name [String] The name of this module.
      # @param final [Boolean] Whether this namespace is final.
      # @param interface [Boolean] A boolean indicating whether this module is an
      #   interface.
      # @param block A block which the new instance yields itself to.
      # @return [void]
      def initialize(generator, name, final, interface, &block)
        super(generator, name, final, &block)
        @name = name
        @interface = interface
      end

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this module.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)        
        lines = generate_comments(indent_level, options)
        lines << options.indented(indent_level, "module #{name}")
        lines += [options.indented(indent_level + 1, "interface!"), ""] if interface
        lines += generate_body(indent_level + 1, options)
        lines << options.indented(indent_level, "end")
      end

      sig { returns(T::Boolean) }
      # A boolean indicating whether this module is an interface or not.
      # @return [Boolean]
      attr_reader :interface

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {ModuleNamespace} instances, returns true if they may
      # be merged into this instance using {merge_into_self}. For instances to
      # be mergeable, they must either all be interfaces or all not be 
      # interfaces.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {ModuleNamespace} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        others = T.cast(others, T::Array[RbiGenerator::ModuleNamespace]) rescue (return false)
        all = others + [self]

        all.map(&:interface).uniq.length == 1
      end

      sig do 
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {ModuleNamespace} instances, merges them into this one.
      # You MUST ensure that {mergeable?} is true for those instances.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {ModuleNamespace} instances.
      # @return [void]
      def merge_into_self(others)
        super
      end

      sig { override.returns(String) }
      # Returns a human-readable brief string description of this module.
      # @return [String]
      def describe
        "Module #{name} - #{"interface, " if interface}#{children.length} " +
          "children, #{includes.length} includes, #{extends.length} extends"
      end
    end
  end
end
