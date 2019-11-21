# typed: true
module Parlour
  class RbiGenerator
    # Represents an enum definition; that is, a class with an +enum+ call.
    class EnumClassNamespace < ClassNamespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          enums: T::Array[T.any([String, String], String)],
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: EnumClassNamespace).void)
        ).void
      end
      # Creates a new enum class definition.
      # @note You should use {Namespace#create_class} rather than this directly.
      #
      # @param generator [RbiGenerator] The current RbiGenerator.
      # @param name [String] The name of this class.
      # @param final [Boolean] Whether this namespace is final.
      # @param enums [Array<(String, String), String>] The values of the enumeration.
      # @param abstract [Boolean] A boolean indicating whether this class is abstract.
      # @param block A block which the new instance yields itself to.
      # @return [void]
      def initialize(generator, name, final, enums, abstract, &block)
        super(generator, name, final, 'T::Enum', abstract, &block)
        @enums = enums
      end

      sig { returns(T::Array[T.any([String, String], String)]) }
      # The values of the enumeration.
      # @return [Array<(String, String), String>]
      attr_reader :enums

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for the body of this enum. This consists of
      # {enums}, {includes}, {extends} and {children}.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines for the body, formatted as specified.
      def generate_body(indent_level, options)
        result = [options.indented(indent_level, 'enums do')]
        enums.each do |enum_value|
          case enum_value
          when String
            line = "#{enum_value} = new"
          when Array
            line = "#{enum_value[0]} = new(#{enum_value[1]})"
          else
            T.absurd(enum_value)
          end

          result << options.indented(indent_level + 1, line)
        end
        result << options.indented(indent_level, 'end')
        result << ''

        result + super
      end

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {EnumClassNamespace} instances, returns true if they may
      # be merged into this instance using {merge_into_self}. For instances to
      # be mergeable, they must either all be abstract or all not be abstract,
      # and they must define the same superclass (or none at all).
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {EnumClassNamespace} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        others = T.cast(others, T::Array[EnumClassNamespace]) rescue (return false)
        all = others + [self]

        T.must(super && all.map(&:enums).uniq.length <= 1)
      end
    end
  end
end