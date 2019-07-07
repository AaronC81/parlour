# typed: true
module Parlour
  class RbiGenerator
    # Represents an attribute reader, writer or accessor.
    class Attribute < Method
      sig do
        params(
          generator: RbiGenerator,
          name: String,
          kind: Symbol,
          type: String,
          block: T.nilable(T.proc.params(x: Method).void)
        ).void
      end
      # Creates a new attribute.
      # @note You should use {Namespace#create_attribute} rather than this directly.
      #
      # @param generator [RbiGenerator] The current RbiGenerator.
      # @param name [String] The name of this attribute.
      # @param kind [Symbol] The kind of attribute this is; one of :writer, :reader or
      #   :accessor.
      # @param type [String] A Sorbet string of this attribute's type, such as
      #   +"String"+ or +"T.untyped"+.
      # @param block A block which the new instance yields itself to.
      # @return [void]
      def initialize(generator, name, kind, type, &block)
        # According to this source: 
        #   https://github.com/sorbet/sorbet/blob/2275752e51604acfb79b30a0a96debc996c089d9/test/testdata/dsl/attr_multi.rb
        # attr_accessor and attr_reader should have: sig { returns(X) }
        # attr_writer :foo should have: sig { params(foo: X).returns(X) }

        @kind = kind
        case kind
        when :accessor, :reader
          super(generator, name, [], type, &block)
        when :writer
          super(generator, name, [
            Parameter.new(name, type: type)
          ], type, &block)
        else
          raise 'unknown kind'
        end
      end

      sig { returns(Symbol) }
      # The kind of attribute this is; one of +:writer+, +:reader+, or +:accessor+.
      # @return [Symbol]
      attr_reader :kind

      private

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBI lines for this method.
      # 
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBI lines, formatted as specified.
      def generate_definition(indent_level, options)
        [options.indented(indent_level, "attr_#{kind} :#{name}")]
      end
    end
  end
end
