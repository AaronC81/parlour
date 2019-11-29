# typed: true

module Parser
  module AST
    class Node
      sig { returns(T::Array[T.untyped]) }
      def to_a; end

      sig { returns(Symbol) }
      def type; end
    end
  end

  class CurrentRuby
    sig { params(buffer: Source::Buffer).returns(AST::Node) }
    def parse(buffer); end
  end

  module Source
    class Buffer
      sig { params(filename: String).void }
      def initialize(filename); end

      sig { returns(String) }
      attr_accessor :source
    end
  end
end
