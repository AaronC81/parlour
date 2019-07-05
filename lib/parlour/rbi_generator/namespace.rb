# typed: true
module Parlour
  class RbiGenerator
    # A generic namespace. This shouldn't be used, except as the type of
    # {RbiGenerator#root}.
    class Namespace < RbiObject
      extend T::Sig

      sig do
        implementation.overridable.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this namespace.
      # @param indent_level The indentation level to generate the lines at.
      # @param options The formatting options to use.
      # @return The RBI lines, formatted as specified.
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
      # Generates the RBI lines for the body of this namespace. This consists of
      # {includes}, {extends} and {children}.
      # @param indent_level The indentation level to generate the lines at.
      # @param options The formatting options to use.
      # @return The RBI lines for the body, formatted as specified.
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
      # Creates a new namespace. Unless you're doing something impressively 
      # hacky, this shouldn't be invoked outside of {RbiGenerator#initialize}.
      # @param generator The current RbiGenerator.
      # @param name The name of this module.
      # @param block A block which the new instance yields itself to.
      def initialize(generator, name = nil, &block)
        super(generator, name || '<anonymous namespace>')
        @children = []
        @extends = []
        @includes = []
        yield_self(&block)
      end

      sig { returns(T::Array[RbiObject]) }
      # The child {RbiObject} instances inside this namespace.
      attr_reader :children

      sig { returns(T::Array[String]) }
      # A list of strings which are each used in an +extend+ statement in this
      # namespace.
      attr_reader :extends

      sig { returns(T::Array[String]) }
      # A list of strings which are each used in an +include+ statement in this
      # namespace.
      attr_reader :includes

      sig do
        params(
          name: String,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ClassNamespace)
      end
      # Creates a new class definition as a child of this namespace.
      # @param name The name of this class.
      # @param superclass The superclass of this class, or nil if it doesn't
      #   have one.
      # @param abstract A boolean indicating whether this class is abstract.
      # @param block A block which the new instance yields itself to.
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
      # Creates a new module definition as a child of this namespace.
      # @param name The name of this module.
      # @param interface A boolean indicating whether this module is an
      #   interface.
      # @param block A block which the new instance yields itself to.
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
      # Creates a new method definition as a child of this namespace.
      # @param name The name of this method. You should not specify +self.+ in
      #   this - use the +class_method+ parameter instead.
      # @param parameters An array of {Parameter} instances representing this 
      #   method's parameters.
      # @param return_type A Sorbet string of what this method returns, such as
      #   +"String"+ or +"T.untyped"+. Passing nil denotes a void return.
      # @param abstract Whether this method is abstract.
      # @param implementation Whether this method is an implementation of a
      #   parent abstract method.
      # @param override Whether this method is overriding a parent overridable
      #   method.
      # @param overridable Whether this method is overridable by subclasses.
      # @param class_method Whether this method is a class method; that is, it
      #   it is defined using +self.+.
      # @param block A block which the new instance yields itself to.
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
      # Adds a new +extend+ to this namespace.
      # @param name A code string for what is extended, for example
      #   +"MyModule"+.
      def add_extend(name)
        extends << name
      end

      sig { params(name: String).void }
      # Adds a new +include+ to this namespace.
      # @param name A code string for what is included, for example
      #   +"Enumerable"+.
      def add_include(name)
        includes << name
      end

      sig do
        implementation.overridable.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {Namespace} instances, returns true if they may be
      # merged into this instance using {merge_into_self}. All bare namespaces
      # can be merged into each other, as they lack definitions for themselves,
      # so there is nothing to conflict. (This isn't the case for subclasses
      # such as {ClassNamespace}.)
      # @param others An array of other {Namespace} instances.
      # @return Always true.
      def mergeable?(others)
        true
      end

      sig do 
        implementation.overridable.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {Namespace} instances, merges them into this one.
      # All children, extends and includes are copied into this instance.
      # @param others An array of other {Namespace} instances.
      def merge_into_self(others)
        others.each do |other|
          other = T.cast(other, Namespace)

          other.children.each { |c| children << c }
          other.extends.each { |e| extends << e }
          other.includes.each { |i| includes << i }
        end
      end

      sig { implementation.overridable.returns(String) }
      # Returns a human-readable brief string description of this namespace.
      def describe
        "Namespace #{name} - #{children.length} children, #{includes.length} " +
          "includes, #{extends.length} extends"
      end
    end
  end
end