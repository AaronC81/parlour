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
        super(&block)
        @name = name
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

      sig { returns(String) }
      attr_reader :name

      sig { returns(T.nilable(String)) }
      attr_reader :superclass

      sig { returns(T::Boolean) }
      attr_reader :abstract
    end
  end
end