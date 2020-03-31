# typed: true

module Parser
  module AST
    class Node
      sig { returns(T::Array[T.untyped]) }
      def to_a; end

      sig { returns(Symbol) }
      def type; end

      sig { returns(Source::Map) }
      def loc; end

      sig { params(type: Symbol, children: Array, properties: Hash).void }
      def initialize(type, children=[], properties={}); end
    end
  end

  class CurrentRuby
    sig { params(buffer: Source::Buffer).returns(T.nilable(AST::Node)) }
    def parse(buffer); end
  end

  module Source
    class Range
      sig { returns(Integer) }
      def begin_pos; end

      sig { returns(Integer) }
      def end_pos; end

      sig { returns(Buffer) }
      def source_buffer; end
    end

    class Map
      sig { returns(Source::Range) }
      def expression; end
    end

    class Buffer
      sig { params(filename: String).void }
      def initialize(filename); end

      sig { returns(String) }
      attr_accessor :source
    end
  end
end
