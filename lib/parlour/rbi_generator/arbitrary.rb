# typed: true
module Parlour
  class RbiGenerator
    # Represents miscellaneous Ruby code.
    class Arbitrary < RbiObject
      sig do
        params(
          generator: RbiGenerator,
          code: String,
          block: T.nilable(T.proc.params(x: Arbitrary).void)
        ).void
      end
      # Creates new arbitrary code.
      #
      # @param code [String] The arbitrary code string. Indentation is added to
      #   the beginning of each line.
      def initialize(generator, code: '', &block)
        super(generator, '')
        @code = code
        yield_self(&block) if block
      end

      sig { returns(String) }
      # Returns arbitrary code string.
      attr_accessor :code

      sig { params(other: Object).returns(T::Boolean) }
      # Returns true if this instance is equal to another arbitrary code line.
      #
      # @param other [Object] The other instance. If this is not a {Arbitrary} (or a
      #   subclass of it), this will always return false.
      # @return [Boolean]
      def ==(other)
        Arbitrary === other && code == other.code
      end

      sig do
        implementation.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this arbitrary code.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        code.split("\n").map { |l| options.indented(indent_level, l) }
      end

      sig do
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {Arbitrary} instances, returns true if they may be 
      # merged into this instance using {merge_into_self}. This is always false.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {Arbitrary} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        false
      end

      sig do 
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {Arbitrary} instances, merges them into this one.
      # This particular implementation always throws an exception, because
      # {mergeable?} is always false.
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other
      #   {Arbitrary} instances.
      # @return [void]
      def merge_into_self(others)
        raise 'arbitrary code is never mergeable'
      end

      sig { override.returns(String) }
      # Returns a human-readable brief string description of this code.
      #
      # @return [String]
      def describe
        "Arbitrary code (#{code})"
      end
    end
  end
end
