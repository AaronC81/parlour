# typed: true
module Parlour
  class RbsGenerator < Generator
    # Represents one signature in a method definition.
    # (This is not an RbsObject because it doesn't generate a full line.)
    class MethodSignature
      extend T::Sig

      sig do
        params(
          parameters: T::Array[Parameter],
          return_type: T.nilable(Types::TypeLike),
          block: T.nilable(Block),
          type_parameters: T.nilable(T::Array[Symbol])
        ).void
      end
      # Creates a new method signature.
      #
      # @param parameters [Array<Parameter>] An array of {Parameter} instances representing this 
      #   method's parameters.
      # @param return_type [Types::TypeLike, nil] What this method returns. Passing nil denotes a void return.
      # @param block [Types::TypeLike, nil] The block this method accepts. Passing nil denotes none.
      # @param class_method [Boolean] Whether this method is a class method; that is, it
      #   it is defined using +self.+.
      # @param type_parameters [Array<Symbol>, nil] This method's type parameters.
      # @return [void]
      def initialize(parameters, return_type = nil, block: nil, type_parameters: nil)
        @parameters = parameters
        @return_type = return_type
        @block = block
        @type_parameters = type_parameters || []
      end

      sig { overridable.params(other: Object).returns(T::Boolean).checked(:never) }
      # Returns true if this instance is equal to another method signature.
      #
      # @param other [Object] The other instance. If this is not a {MethodSignature} (or a
      #   subclass of it), this will always return false.
      # @return [Boolean]
      def ==(other)
        MethodSignature === other &&
          parameters      == other.parameters &&
          return_type     == other.return_type &&
          type_parameters == other.type_parameters
      end

      sig { returns(T::Array[Parameter]) }
      # An array of {Parameter} instances representing this method's parameters.
      # @return [Array<Parameter>]
      attr_reader :parameters

      sig { returns(T.nilable(Types::TypeLike)) }
      # What this method returns. Passing nil denotes a void return.
      # @return [Types::TypeLike, nil]
      attr_reader :return_type

      sig { returns(T::Boolean) }
      # Whether this method is a class method; that is, it it is defined using
      # +self.+.
      # @return [Boolean]
      attr_reader :class_method

      sig { returns(T::Array[Symbol]) }
      # This method's type parameters.
      # @return [Array<Symbol>]
      attr_reader :type_parameters

      sig { params(options: Options).returns(T::Array[String]) }
      # Generates the RBS string for this signature.
      #
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBS string, formatted as specified.
      def generate_rbs(options)
        # TODO: ignores formatting options

        block_param = parameters.find { |x| x.kind == :block }
        block_type = block_param&.type
        block_type = String === block_type ? block_type : block_type&.generate_rbs

        rbs_params = parameters.reject { |x| x.kind == :block }.map(&:to_rbs_param)
        rbs_return_type = String === @return_type ? @return_type : @return_type&.generate_rbs

        ["#{
          type_parameters.any? ? "[#{type_parameters.join(', ')}] " : '' 
        }(#{rbs_params.join(', ')}) #{
          (block_type && block_type != 'untyped') ? "{ #{block_type} } " : ''
        }-> #{rbs_return_type || 'void'}"]
      end
    end
  end
end
