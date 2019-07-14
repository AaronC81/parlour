# typed: true
module Parlour
  class RbiGenerator
    # Represents an +extend+ call.
    class Extend < RbiObject
      sig do
        params(
          generator: RbiGenerator,
          object: String,
          block: T.nilable(T.proc.params(x: Extend).void)
        ).void
      end
      # Creates a new +extend+ call.
      #
      # @param object [String] The name of the object to be extended.
      def initialize(generator, object: '', &block)
        super(generator, '')
        @object = object
        yield_self(&block)
      end

      sig { returns(String) }
      # Returns the name of the object to be extended.
      attr_accessor :object

      sig { params(other: Object).returns(T::Boolean) }
      # Returns true if this instance is equal to another extend.
      #
      # @param other [Object] The other instance. If this is not a {Extend} (or a
      #   subclass of it), this will always return false.
      # @return [Boolean]
      def ==(other)
        Extend === other && object == other.object
      end

      sig do
        implementation.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this extend.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        [options.indented(indent_level, "extend #{object}")]
      end

      sig do
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {Extend} instances, returns true if they may be 
      # merged into this instance using {merge_into_self}. This is always false.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {Extend} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        false
      end

      sig do 
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {Extend} instances, merges them into this one.
      # This particular implementation will simply do nothing, as instances
      # are only mergeable if they are indentical.
      # You MUST ensure that {mergeable?} is true for those instances.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {Extend} instances.
      # @return [void]
      def merge_into_self(others)
        # We don't need to change anything! We only merge identical extends
      end

      sig { override.returns(String) }
      # Returns a human-readable brief string description of this code.
      #
      # @return [String]
      def describe
        "Extend (#{object})"
      end
    end
  end
end
