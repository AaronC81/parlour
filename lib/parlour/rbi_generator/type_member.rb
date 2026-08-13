# typed: true
module Parlour
  class RbiGenerator < Generator
    # Represents a type member: a class- or module-scoped type parameter,
    # declared with Sorbet's +T::Generic+ (+Elem = type_member+).
    class TypeMember < RbiObject
      sig { params(generator: Generator, name: String, block: T.nilable(T.proc.params(x: TypeMember).void)).void }
      # Creates a new type member.
      #
      # @param name [String] The name of the type member.
      # @param block A block which the new instance yields itself to.
      def initialize(generator, name:, &block)
        super(generator, name)
        yield_self(&block) if block
      end

      sig { params(other: Object).returns(T::Boolean) }
      # Returns true if this instance is equal to another type member.
      #
      # @param other [Object] The other instance. If this is not a {TypeMember} (or a
      #   subclass of it), this will always return false.
      # @return [Boolean]
      def ==(other)
        TypeMember === other && name == other.name
      end

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this type member.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        [options.indented(indent_level, "#{name} = type_member")]
      end

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {TypeMember} instances, returns true if they may be
      # merged into this instance using {merge_into_self}. This is always false.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {TypeMember} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        others.all? { |other| self == other }
      end

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {TypeMember} instances, merges them into this one.
      # This particular implementation will simply do nothing, as instances
      # are only mergeable if they are identical.
      # You MUST ensure that {mergeable?} is true for those instances.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {TypeMember} instances.
      # @return [void]
      def merge_into_self(others)
        # We don't need to change anything! We only merge identical type members
      end

      sig { override.void }
      def generalize_from_rbi!
        # Nothing to generalize; a type member has no type of its own.
      end

      sig { override.returns(T::Array[T.any(Symbol, T::Hash[Symbol, String])]) }
      def describe_attrs
        []
      end
    end
  end
end
