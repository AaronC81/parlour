# typed: true
module Parlour
  # A generic superclass of all objects which form part of type definitions in,
  # specific formats, such as RbiObject and RbsObject.
  class TypedObject
    extend T::Sig
    extend T::Helpers
    abstract!

    sig { params(name: String).void }
    # Create a new typed object.
    def initialize(name)
      @name = name
      @comments = []
    end

    sig { returns(T.nilable(Plugin)) }
    # The {Plugin} which was controlling the {generator} when this object was
    # created.
    # @return [Plugin, nil]
    attr_reader :generated_by

    sig { returns(String).checked(:never) }
    # The name of this object.
    # @return [String]
    attr_reader :name

    sig { returns(T::Array[String]) }
    # An array of comments which will be placed above the object in the RBS
    # file.
    # @return [Array<String>]
    attr_reader :comments

    sig { params(comment: T.any(String, T::Array[String])).void }
    # Adds one or more comments to this RBS object. Comments always go above 
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

    sig { abstract.returns(String) }
    # Returns a human-readable brief string description of this object. This
    # is displayed during manual conflict resolution with the +parlour+ CLI.
    #
    # @abstract
    # @return [String]
    def describe; end
    
    protected

    sig do
      params(
        indent_level: Integer,
        options: Options
      ).returns(T::Array[String])
    end
    # Generates the RBS lines for this object's comments.
    #
    # @param indent_level [Integer] The indentation level to generate the lines at.
    # @param options [Options] The formatting options to use.
    # @return [Array<String>] The RBS lines for each comment, formatted as specified.
    def generate_comments(indent_level, options)
      comments.any? \
        ? comments.map { |c| options.indented(indent_level, "# #{c}") }
        : []
    end
  end
end
