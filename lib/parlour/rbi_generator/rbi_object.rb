# typed: true
module Parlour
  class RbiGenerator
    # An abstract class which is subclassed by any classes which can generate
    # entire lines of an RBI, such as {Namespace} and {Method}. (As an example,
    # {Parameter} is _not_ a subclass because it does not generate lines, only
    # segments of definition and signature lines.)
    # @abstract
    class RbiObject
      extend T::Helpers
      extend T::Sig
      abstract!

      sig { params(generator: RbiGenerator, name: String).void }
      # Creates a new RBI object.
      # @note Don't call this directly.
      #
      # @param generator [RbiGenerator] The current RbiGenerator.
      # @param name [String] The name of this module.
      # @return [void]
      def initialize(generator, name)
        @generator = generator
        @generated_by = generator.current_plugin
        @name = name
        @comments = []
      end

      sig { returns(RbiGenerator) }
      # The generator which this object belongs to.
      # @return [RbiGenerator]
      attr_reader :generator

      sig { returns(T.nilable(Plugin)) }
      # The {Plugin} which was controlling the {generator} when this object was
      # created.
      # @return [Plugin, nil]
      attr_reader :generated_by

      sig { returns(String) }
      # The name of this object.
      # @return [String]
      attr_reader :name

      sig { returns(T::Array[String]) }
      # An array of comments which will be placed above the object in the RBI
      # file.
      # @return [Array<String>]
      attr_reader :comments

      sig { params(comment: T.any(String, T::Array[String])).void }
      # Adds one or more comments to this RBI object. Comments always go above 
      # the definition for this object, not in the definition's body.
      #
      # @example Creating a module with a comment.
      #   namespace.create_module('M') do |m|
      #     m.add_comment('This is a module')
      #   end
      #
      # @example Creating a class with a multi-line comment.
      #   namespace.create_class('C') do |c|
      #     c.add_comment(['This is a multi-line comment!', 'It can be as long as you want!'])
      #   end
      #
      # @param comment [String, Array<String>] The new comment(s).
      # @return [void]
      def add_comment(comment)
        if comment.is_a?(String)
          comments << comment
        elsif comment.is_a?(Array)
          comments.concat(comment)
        end
      end

      alias_method :add_comments, :add_comment

      sig do
        abstract.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this object.
      #
      # @abstract
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options); end

      sig do
        abstract.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of other objects, returns true if they may be merged
      # into this instance using {merge_into_self}. Each subclass will have its
      # own criteria on what allows objects to be mergeable.
      #
      # @abstract
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {RbiObject} instances.
      # @return [Boolean] Whether this instance may be merged with them.
      def mergeable?(others); end

      sig do 
        abstract.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of other objects, merges them into this one. Each
      # subclass will do this differently.
      # You MUST ensure that {mergeable?} is true for those instances.
      #
      # @abstract
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {RbiObject} instances.
      # @return [void]
      def merge_into_self(others); end

      sig { abstract.returns(String) }
      # Returns a human-readable brief string description of this object. This
      # is displayed during manual conflict resolution with the +parlour+ CLI.
      #
      # @abstract
      # @return [String]
      def describe; end
      
      private

      sig do
        params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this object's comments.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines for each comment, formatted as specified.
      def generate_comments(indent_level, options)
        comments.any? \
          ? comments.map { |c| options.indented(indent_level, "# #{c}") }
          : []
      end
    end
  end
end
