# typed: true
module Parlour
  class RbiGenerator
    class ClassNamespace < Namespace
      extend T::Sig

      sig do
        params(
          name: String,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).void
      end
      def initialize(name, superclass, abstract, &block)
        super(name, &block)
        @superclass = superclass
        @abstract = abstract
      end

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_rbi(indent_level, options)
        class_definition = superclass.nil? \
          ? "class #{name}"
          : "class #{name} < #{superclass}"
        
        lines = []
        lines << options.indented(indent_level, class_definition)
        lines += [options.indented(indent_level + 1, "abstract!"), ""] if abstract
        lines += super(indent_level + 1, options)
        lines << options.indented(indent_level, "end")
      end

      sig { returns(T.nilable(String)) }
      attr_reader :superclass

      sig { returns(T::Boolean) }
      attr_reader :abstract

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
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
      def merge_into_self(others)
        others.each do |other|
          other = T.cast(other, ClassNamespace)

          other.children.each { |c| children << c }
          other.extends.each { |e| extends << e }
          other.includes.each { |i| includes << i }

          @superclass = other.superclass unless superclass
        end
      end
    end
  end
end