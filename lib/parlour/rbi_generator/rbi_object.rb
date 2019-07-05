# typed: true
module Parlour
  class RbiGenerator
    class RbiObject
      extend T::Helpers
      extend T::Sig
      abstract!

      sig { params(generator: RbiGenerator, name: String).void }
      def initialize(generator, name)
        @generator = generator
        @generated_by = generator.current_plugin
        @name = name
        @comments = []
      end

      sig { returns(RbiGenerator) }
      attr_reader :generator

      sig { returns(T.nilable(Plugin)) }
      attr_reader :generated_by

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[String]) }
      attr_reader :comments

      sig { params(comment: String).void }
      def add_comment(comment)
        comments << comment
      end

      sig do
        params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_comments(indent_level, options)
        comments.any? \
          ? comments.map { |c| options.indented(indent_level, "# #{c}") }
          : []
      end

      sig do
        abstract.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_rbi(indent_level, options); end

      sig do
        abstract.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      def mergeable?(others); end

      sig do 
        abstract.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      def merge_into_self(others); end

      sig { abstract.returns(String) }
      def describe; end
    end
  end
end