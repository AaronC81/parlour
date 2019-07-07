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
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        generate_comments(indent_level, options) +  
          generate_body(indent_level, options)
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
      #
      # @param generator [RbiGenerator] The current RbiGenerator.
      # @param name [String, nil] The name of this module.
      # @param block A block which the new instance yields itself to.
      # @return [void]
      def initialize(generator, name = nil, &block)
        super(generator, name || '<anonymous namespace>')
        @children = []
        @extends = []
        @includes = []
        @constants = []
        yield_self(&block)
      end

      sig { returns(T::Array[RbiObject]) }
      # The child {RbiObject} instances inside this namespace.
      # @return [Array<RbiObject>]
      attr_reader :children

      sig { returns(T::Array[String]) }
      # A list of strings which are each used in an +extend+ statement in this
      # namespace.
      # @return [Array<String>]
      attr_reader :extends

      sig { returns(T::Array[String]) }
      # A list of strings which are each used in an +include+ statement in this
      # namespace.
      # @return [Array<String>]
      attr_reader :includes

      sig { returns(T::Array[[String, String]]) }
      # A list of constants which are defined in this namespace, in the form of
      # pairs [name, value].
      # @return [Array<(String, String)>]
      attr_reader :constants

      sig do
        params(
          name: String,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ClassNamespace)
      end
      # Creates a new class definition as a child of this namespace.
      #
      # @param name [String] The name of this class.
      # @param superclass [String, nil] The superclass of this class, or nil if it doesn't
      #   have one.
      # @param abstract [Boolean] A boolean indicating whether this class is abstract.
      # @param block A block which the new instance yields itself to.
      # @return [ClassNamespace]
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
      #
      # @param name [String] The name of this module.
      # @param interface [Boolean] A boolean indicating whether this module is an
      #   interface.
      # @param block A block which the new instance yields itself to.
      # @return [ModuleNamespace]
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
      #
      # @param name [String] The name of this method. You should not specify +self.+ in
      #   this - use the +class_method+ parameter instead.
      # @param parameters [Array<Parameter>] An array of {Parameter} instances representing this 
      #   method's parameters.
      # @param return_type [String, nil] A Sorbet string of what this method returns, such as
      #   +"String"+ or +"T.untyped"+. Passing nil denotes a void return.
      # @param abstract [Boolean] Whether this method is abstract.
      # @param implementation [Boolean] Whether this method is an implementation of a
      #   parent abstract method.
      # @param override [Boolean] Whether this method is overriding a parent overridable
      #   method.
      # @param overridable [Boolean] Whether this method is overridable by subclasses.
      # @param class_method [Boolean] Whether this method is a class method; that is, it
      #   it is defined using +self.+.
      # @param block A block which the new instance yields itself to.
      # @return [Method]
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

      # Creates a new attribute.
      #
      # @example Create an +attr_reader+.
      #   module.create_attribute('readable', :reader, 'String')
      #   # #=> sig { returns(String) }
      #   #     attr_reader :readable
      #
      # @example Create an +attr_writer+.
      #   module.create_attribute('writable', :writer, 'Integer')
      #   # #=> sig { params(writable: Integer).returns(Integer) }
      #   #     attr_writer :writable
      #
      # @example Create an +attr_accessor+.
      #   module.create_attribute('accessible', :accessor, 'T::Boolean')
      #   # #=> sig { returns(T::Boolean) }
      #   #     attr_accessor :accessible
      #
      # @param name [String] The name of this attribute.
      # @param kind [Symbol] The kind of attribute this is; one of +:writer+, +:reader+, or
      #   +:accessor+.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Attribute]
      def create_attribute(name, kind, type, &block)
        new_attribute = RbiGenerator::Attribute.new(
          generator,
          name,
          kind,
          type,
          &block
        )
        children << new_attribute
        new_attribute
      end
      alias_method :create_attr, :create_attribute

      # Creates a new read-only attribute (+attr_reader+).
      #
      # @param name [String] The name of this attribute.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Attribute]
      def create_attr_reader(name, type, &block)
        create_attribute(name, :reader, type, &block)
      end

      # Creates a new write-only attribute (+attr_writer+).
      #
      # @param name [String] The name of this attribute.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Attribute]
      def create_attr_writer(name, type, &block)
        create_attribute(name, :writer, type, &block)
      end

      # Creates a new read and write attribute (+attr_accessor+).
      #
      # @param name [String] The name of this attribute.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Attribute]
      def create_attr_accessor(name, type, &block)
        create_attribute(name, :accessor, type, &block)
      end

      sig { params(name: String).void }
      # Adds a new +extend+ to this namespace.
      #
      # @param name [String] A code string for what is extended, for example
      #   +"MyModule"+.
      # @return [void]
      def add_extend(name)
        extends << name
      end

      sig { params(name: String).void }
      # Adds a new +include+ to this namespace.
      #
      # @param name [String] A code string for what is included, for example
      #   +"Enumerable"+.
      # @return [void]
      def add_include(name)
        includes << name
      end

      sig { params(name: String, value: String).void }
      # Adds a new constant definition to this namespace.
      #
      # @param name [String] The name of the constant.
      # @param value [String] A Ruby code string for this constant's value, for
      #   example +"3.14"+ or +"T.type_alias(X)"+
      # @return [void]
      def add_constant(name, value)
        constants << [name, value]
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
      # 
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {Namespace} instances.
      # @return [true] Always true.
      def mergeable?(others)
        true
      end

      sig do 
        implementation.overridable.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {Namespace} instances, merges them into this one.
      # All children, constants, extends and includes are copied into this 
      # instance.
      # 
      # @param others [Array<RbiGenerator::RbiObject>] An array of other {Namespace} instances.
      # @return [void]
      def merge_into_self(others)
        others.each do |other|
          other = T.cast(other, Namespace)

          other.children.each { |c| children << c }
          other.extends.each { |e| extends << e }
          other.includes.each { |i| includes << i }
          other.constants.each { |i| constants << i }
        end
      end

      sig { implementation.overridable.returns(String) }
      # Returns a human-readable brief string description of this namespace.
      #
      # @return [String]
      def describe
        "Namespace #{name} - #{children.length} children, #{includes.length} " +
          "includes, #{extends.length} extends, #{constants.length} constants"
      end

      private

      sig do
        params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for the body of this namespace. This consists of
      # {includes}, {extends} and {children}.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines for the body, formatted as specified.
      def generate_body(indent_level, options)
        result = []

        if includes.any? || extends.any? || constants.any?
          result += includes.map do |i|
            options.indented(indent_level, "include #{i}")
          end
          result += extends.map do |e|
            options.indented(indent_level, "extend #{e}")
          end
          result += constants.map do |c|
            name, value = c
            options.indented(indent_level, "#{name} = #{value}")
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
    end
  end
end
