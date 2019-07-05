# typed: true
module Parlour
  class RbiGenerator
    class Namespace < RbiObject
      extend T::Sig

      sig do
        implementation.overridable.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_rbi(indent_level, options)
        generate_comments(indent_level, options) +  
          generate_body(indent_level, options)
      end

      sig do
        params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_body(indent_level, options)
        result = []

        if includes.any? || extends.any?
          result += includes.map do |i|
            options.indented(indent_level, "include #{i}")
          end
          result += extends.map do |e|
            options.indented(indent_level, "extend #{e}")
          end
          result << ""
        end

        first, *rest = children
        return [] unless first

        result += first.generate_rbi(indent_level, options) + T.must(rest)
          .map { |obj| obj.generate_rbi(indent_level, options) }
          .map { |lines| [""] + lines }
          .flatten

        result
      end

      sig do
        params(
          generator: RbiGenerator,
          name: T.nilable(String),
          block: T.nilable(T.proc.params(x: Namespace).void)
        ).void
      end
      def initialize(generator, name = nil, &block)
        super(generator, name || '<anonymous namespace>')
        @children = []
        @extends = []
        @includes = []
        yield_self(&block)
      end

      sig { returns(T::Array[RbiObject]) }
      attr_reader :children

      sig { returns(T::Array[String]) }
      attr_reader :extends

      sig { returns(T::Array[String]) }
      attr_reader :includes

      sig do
        params(
          name: String,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ClassNamespace)
      end
      def create_class(name, superclass: nil, abstract: false, &block)
        new_class = ClassNamespace.new(generator, name, superclass, abstract, &block)
        children << new_class
        new_class
      end

      sig do
        params(
          name: String,
          interface: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ModuleNamespace)
      end
      def create_module(name, interface: false, &block)
        new_module = ModuleNamespace.new(generator, name, interface, &block)
        children << new_module
        new_module
      end

      sig do
        params(
          name: String,
          parameters: T::Array[Parameter],
          return_type: T.nilable(String),
          abstract: T::Boolean,
          implementation: T::Boolean,
          override: T::Boolean,
          overridable: T::Boolean,
          class_method: T::Boolean,
          block: T.nilable(T.proc.params(x: Method).void)
        ).returns(Method)
      end
      def create_method(name, parameters, return_type = nil, abstract: false, implementation: false, override: false, overridable: false, class_method: false, &block)
        new_method = RbiGenerator::Method.new(
          generator,
          name,
          parameters,
          return_type,
          abstract: abstract,
          implementation: implementation, 
          override: override,
          overridable: overridable,
          class_method: class_method,
          &block
        )
        children << new_method
        new_method
      end

      sig { params(name: String).void }
      def add_extend(name)
        extends << name
      end
      sig { params(name: String).void }
      def add_include(name)
        includes << name
      end

      sig do
        implementation.overridable.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      def mergeable?(others)
        true
      end

      sig do 
        implementation.overridable.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      def merge_into_self(others)
        others.each do |other|
          other = T.cast(other, Namespace)

          other.children.each { |c| children << c }
          other.extends.each { |e| extends << e }
          other.includes.each { |i| includes << i }
        end
      end

      sig { implementation.overridable.returns(String) }
      def describe
        "Namespace #{name} - #{children.length} children, #{includes.length} " +
          "includes, #{extends.length} extends"
      end
    end
  end
end