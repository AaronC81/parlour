# typed: true
module Parlour
  class RbiGenerator
    class Method < RbiObject
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          parameters: T::Array[Parameter],
          return_type: T.nilable(String),
          abstract: T::Boolean,
          implementation: T::Boolean,
          override: T::Boolean,
          overridable: T::Boolean,
          class_method: T::Boolean,
          block: T.nilable(T.proc.params(x: Method).void)
        ).void
      end
      # Creates a new method definition. (You should use
      # {Namespace#create_method} rather than this directly.)
      # @param generator The current RbiGenerator.
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
      def initialize(generator, name, parameters, return_type = nil, abstract: false, implementation: false, override: false, overridable: false, class_method: false, &block)
        super(generator, name)
        @parameters = parameters
        @return_type = return_type
        @abstract = abstract
        @implementation = implementation
        @override = override
        @overridable = overridable
        @class_method = class_method
        yield_self(&block)
      end

      sig { params(other: Object).returns(T::Boolean) }
      # Returns true if this instance is equal to another method.
      # @param other The other instance. If this is not a {Method} (or a
      #   subclass of it), this will always return false.
      def ==(other)
        Method === other &&
          name           == other.name && 
          parameters     == other.parameters &&
          return_type    == other.return_type &&
          abstract       == other.abstract &&
          implementation == other.implementation &&
          override       == other.override &&
          overridable    == other.overridable &&
          class_method   == other.class_method
      end

      sig { returns(T::Array[Parameter]) }
      # An array of {Parameter} instances representing this method's parameters.
      attr_reader :parameters

      sig { returns(T.nilable(String)) }
      # A Sorbet string of what this method returns, such as "String" or
      # "T.untyped". Passing nil denotes a void return.
      attr_reader :return_type

      sig { returns(T::Boolean) }
      # Whether this method is abstract.
      attr_reader :abstract

      sig { returns(T::Boolean) }
      # Whether this method is an implementation of a parent abstract method.
      attr_reader :implementation

      sig { returns(T::Boolean) }
      # Whether this method is overriding a parent overridable method.
      attr_reader :override

      sig { returns(T::Boolean) }
      # Whether this method is overridable by subclasses.
      attr_reader :overridable

      sig { returns(T::Boolean) }
      # Whether this method is a class method; that is, it it is defined using
      # +self.+.
      attr_reader :class_method

      sig do
        implementation.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this method.
      # @param indent_level The indentation level to generate the lines at.
      # @param options The formatting options to use.
      # @return The RBI lines, formatted as specified.
      def generate_rbi(indent_level, options)
        return_call = return_type ? "returns(#{return_type})" : 'void'

        sig_params = parameters.map(&:to_sig_param)
        sig_lines = parameters.length >= options.break_params \
          ? [
              options.indented(indent_level, 'sig do'),
              options.indented(indent_level + 1, "#{qualifiers}params("),
            ] +
            (
              parameters.empty? ? [] : sig_params.map do |x|
                options.indented(indent_level + 2, "#{x},") 
              end
            ) +
            [
              options.indented(indent_level + 1, ").#{return_call}"),
              options.indented(indent_level, 'end')
            ]

          : [options.indented(
              indent_level,
              "sig { #{qualifiers}#{
                parameters.empty? ? '' : "params(#{sig_params.join(', ')})"
              }#{
                qualifiers.empty? && parameters.empty? ? '' : '.'
              }#{return_call} }"
            )]

        def_params = parameters.map(&:to_def_param)
        name_prefix = class_method ? 'self.' : ''
        def_line = options.indented(
          indent_level,
          "def #{name_prefix}#{name}(#{def_params.join(', ')}); end"
        )

        generate_comments(indent_level, options) + sig_lines + [def_line]
      end

      sig { returns(String) }
      # Returns the qualifiers which go in front of the +params+ part of this
      # method's Sorbet +sig+. For example, if {abstract} is true, then this
      # will return +abstract.+.
      def qualifiers
        result = ''
        result += 'abstract.' if abstract
        result += 'implementation.' if implementation
        result += 'override.' if override
        result += 'overridable.' if overridable
        result
      end

      sig do
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      # Given an array of {Method} instances, returns true if they may be merged
      # into this instance using {merge_into_self}. For instances to be
      # mergeable, their signatures and definitions must be identical.
      # @param others An array of other {Method} instances.
      # @return Whether this instance may be merged with them.
      def mergeable?(others)
        others.all? { |other| self == other }
      end

      sig do 
        implementation.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      # Given an array of {Method} instances, merges them into this one.
      # This particular implementation in fact does nothing, because {Method}
      # instances are only mergeable if they are identical, so nothing needs
      # to be changed.
      # You MUST ensure that {mergeable?} is true for those instances.
      # @param others An array of other {Method} instances.
      def merge_into_self(others)
        # We don't need to change anything! We only merge identical methods
      end

      sig { override.returns(String) }
      # Returns a human-readable brief string description of this method.
      def describe
        # TODO: more info
        "Method #{name} - #{parameters.length} parameters, " +
          " returns #{return_type}"
      end
    end
  end
end