# typed: true
module Parlour
  class RbiGenerator
    # Represents a class definition.
    class ClassNamespace < Namespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).void
      end
      # Creates a new class definition.
      # @note You should use {Namespace#create_class} rather than this directly.
      #
      # @param generator [RbiGenerator] The current RbiGenerator.
      # @param name [String] The name of this class.
      # @param final [Boolean] Whether this namespace is final.
      # @param superclass [String, nil] The superclass of this class, or nil if it doesn't
      #   have one.
      # @param abstract [Boolean] A boolean indicating whether this class is abstract.
      # @param block A block which the new instance yields itself to.
      # @return [void]
      def initialize(generator, name, final, superclass, abstract, &block)
        super(generator, name, final, &block)
        @superclass = superclass
        @abstract = abstract
      end

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this class.
      # 
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        class_definition = superclass.nil? \
          ? "class #{name}"
          : "class #{name} < #{superclass}"
        
        lines = generate_comments(indent_level, options)
        lines << options.indented(indent_level, class_definition)
        lines += [options.indented(indent_level + 1, "abstract!"), ""] if abstract
        lines += generate_body(indent_level + 1, options)
        lines << options.indented(indent_level, "end")
      end

      sig { returns(T.nilable(String)) }
      # The superclass of this class, or nil if it doesn't have one.
      # @return [String, nil]
      attr_reader :superclass

      sig { returns(T::Boolean) }
      # A boolean indicating whether this class is abstract or not.
      # @return [Boolean]
      attr_reader :abstract

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {ClassNamespace} instances, returns true if they may
      # be merged into this instance using {merge_into_self}. For instances to
      # be mergeable, they must either all be abstract or all not be abstract,
      # and they must define the same superclass (or none at all).
      #
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {ClassNamespace} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others)
        others = T.cast(others, T::Array[ClassNamespace]) rescue (return false)
        all = others + [self]

        all.map(&:abstract).uniq.length == 1 &&
          all.map(&:superclass).compact.uniq.length <= 1
      end

      sig do 
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {ClassNamespace} instances, merges them into this one.
      # You MUST ensure that {mergeable?} is true for those instances.
      # 
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {ClassNamespace} instances.
      # @return [void]
      def merge_into_self(others)
        super

        others.each do |other|
          other = T.cast(other, ClassNamespace)

          @superclass = other.superclass unless superclass
        end
      end

      sig { override.returns(String) }
      # Returns a human-readable brief string description of this class.
      # @return [String]
      def describe
        "Class #{name} - #{"superclass #{superclass}, " if superclass}" +
          "#{"abstract, " if abstract}#{children.length} children, " +
          "#{includes.length} includes, #{extends.length} extends"
      end
    end
  end
end
