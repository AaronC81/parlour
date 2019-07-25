# typed: true
module Parlour
  class RbiGenerator
    # Represents a constant definition.
    class Constant < RbiObject
      sig do
        params(
          generator: RbiGenerator,
          name: String,
          value: String,
          block: T.nilable(T.proc.params(x: Constant).void)
        ).void
      end
      # Creates a new constant definition.
      #
      # @param name [String] The name of the constant.
      # @param value [String] The value of the constant, as a Ruby code string.
      def initialize(generator, name: '', value: '', &block)
        super(generator, name)
        @value = value
        yield_self(&block) if block
      end

      # @return [String] The value of the constant, as a Ruby code string.
      sig { returns(String) }
      attr_reader :value

      sig { params(other: Object).returns(T::Boolean) }
      # Returns true if this instance is equal to another extend.
      #
      # @param other [Object] The other instance. If this is not a {Extend} (or a
      #   subclass of it), this will always return false.
      # @return [Boolean]
      def ==(other)
        Constant === other && name == other.name && value == other.value
      end

      sig do
        implementation.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this constant.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        [options.indented(indent_level, "#{name} = #{value}")]
      end

      sig do
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {Constant} instances, returns true if they may be 
      # merged into this instance using {merge_into_self}. This is always false.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {Constant} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        others.all? { |other| self == other }
      end

      sig do
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {Constant} instances, merges them into this one.
      # This particular implementation will simply do nothing, as instances
      # are only mergeable if they are indentical.
      # You MUST ensure that {mergeable?} is true for those instances.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {Extend} instances.
      # @return [void]
      def merge_into_self(others)
        # We don't need to change anything! We only merge identical constants
      end

      sig { implementation.returns(String) }
      # Returns a human-readable brief string description of this code.
      #
      # @return [String]
      def describe
        "Constant (#{name} = #{value})"
      end
    end
  end
end
