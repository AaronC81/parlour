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
      # Creates a new namespace.
      # @note Unless you're doing something impressively hacky, this shouldn't
      #   be invoked outside of {RbiGenerator#initialize}.
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
        @next_comments = []
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

      sig { params(comment: T.any(String, T::Array[String])).void }
      # Adds one or more comments to the next child RBI object to be created.
      #
      # @example Creating a module with a comment.
      #   namespace.add_comment_to_next_child('This is a module')
      #   namespace.create_module(name: 'M')
      #
      # @example Creating a class with a multi-line comment.
      #   namespace.add_comment_to_next_child(['This is a multi-line comment!', 'It can be as long as you want!'])
      #   namespace.create_class(name: 'C')
      #
      # @param comment [String, Array<String>] The new comment(s).
      # @return [void]
      def add_comment_to_next_child(comment)
        if comment.is_a?(String)
          @next_comments << comment
        elsif comment.is_a?(Array)
          @next_comments.concat(comment)
        end
      end

      sig do
        params(
          name: T.nilable(String),
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ClassNamespace)
      end
      # Creates a new class definition as a child of this namespace.
      #
      # @example Create a class with a nested module.
      #   namespace.create_class(name: 'Foo') do |foo|
      #     foo.create_module(name: 'Bar')
      #   end
      #
      # @example Create a class that is the child of another class.
      #   namespace.create_class(name: 'Bar', superclass: 'Foo') #=> class Bar < Foo
      #
      # @param name [String] The name of this class.
      # @param superclass [String, nil] The superclass of this class, or nil if it doesn't
      #   have one.
      # @param abstract [Boolean] A boolean indicating whether this class is abstract.
      # @param block A block which the new instance yields itself to.
      # @return [ClassNamespace]
      def create_class(name: nil, superclass: nil, abstract: false, &block)
        name = T.must(name)
        new_class = ClassNamespace.new(generator, name, superclass, abstract, &block)
        move_next_comments(new_class)
        children << new_class
        new_class
      end

      sig do
        params(
          name: T.nilable(String),
          interface: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ModuleNamespace)
      end
      # Creates a new module definition as a child of this namespace.
      #
      # @example Create a basic module.
      #   namespace.create_module(name: 'Foo')
      #
      # @example Create a module with a method.
      #   namespace.create_module(name: 'Foo') do |foo|
      #     foo.create_method(name: 'method_name', parameters: [], return_type: 'Integer')
      #   end
      #
      # @param name [String] The name of this module.
      # @param interface [Boolean] A boolean indicating whether this module is an
      #   interface.
      # @param block A block which the new instance yields itself to.
      # @return [ModuleNamespace]
      def create_module(name: nil, interface: false, &block)
        name = T.must(name)
        new_module = ModuleNamespace.new(generator, name, interface, &block)
        move_next_comments(new_module)
        children << new_module
        new_module
      end

      sig do
        params(
          name: T.nilable(String),
          parameters: T.nilable(T::Array[Parameter]),
          return_type: T.nilable(String),
          returns: T.nilable(String),
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
      # @param returns [String, nil] Same as return_type.
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
      def create_method(name: nil, parameters: nil, return_type: nil, returns: nil, abstract: false, implementation: false, override: false, overridable: false, class_method: false, &block)
        name = T.must(name)
        parameters = parameters || []
        raise 'cannot specify both return_type: and returns:' if return_type && returns
        return_type ||= returns
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
        move_next_comments(new_method)
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
      def create_attribute(name: nil, kind: nil, type: nil, &block)
        name = T.must(name)
        kind = T.must(kind)
        type = T.must(type)
        new_attribute = RbiGenerator::Attribute.new(
          generator,
          name,
          kind,
          type,
          &block
        )
        move_next_comments(new_attribute)
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
      def create_attr_reader(name: nil, type: nil, &block)
        create_attribute(name: name, kind: :reader, type: type, &block)
      end

      # Creates a new write-only attribute (+attr_writer+).
      #
      # @param name [String] The name of this attribute.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Attribute]
      def create_attr_writer(name: nil, type: nil, &block)
        create_attribute(name: name, kind: :writer, type: type, &block)
      end

      # Creates a new read and write attribute (+attr_accessor+).
      #
      # @param name [String] The name of this attribute.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Attribute]
      def create_attr_accessor(name: nil, type: nil, &block)
        create_attribute(name: name, kind: :accessor, type: type, &block)
      end

      # Creates a new arbitrary code section.
      # You should rarely have to use this!
      #
      # @param code [String] The code to insert.
      # @param block A block which the new instance yields itself to.
      # @return [RbiGenerator::Arbitrary]
      def create_arbitrary(code: nil, &block)
        code = T.must(code)
        new_arbitrary = RbiGenerator::Arbitrary.new(
          generator,
          code: code,
          &block
        )
        children << new_arbitrary
        new_arbitrary
      end

      sig { params(name: String).void }
      # Adds a new +extend+ to this namespace.
      #
      # @example Add an +extend+ to a class.
      #   class.add_extend('ExtendableClass') #=> extend ExtendableClass
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
      # @example Add an +include+ to a class.
      #   class.add_include('IncludableClass') #=> include IncludableClass
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
        unless first
          # Remove any trailing whitespace due to includes
          result.pop if result.last == ''
          return result
        end

        result += first.generate_rbi(indent_level, options) + T.must(rest)
          .map { |obj| obj.generate_rbi(indent_level, options) }
          .map { |lines| [""] + lines }
          .flatten

        result
      end

      sig { params(object: RbiObject).void }
      # Copies the comments added with {#add_comment_to_next_child} into the
      # given object, and clears the list of pending comments.
      # @param object [RbiObject] The object to move the comments into.
      # @return [void]
      def move_next_comments(object)
        object.comments.prepend(*@next_comments)
        @next_comments.clear
      end
    end
  end
end
