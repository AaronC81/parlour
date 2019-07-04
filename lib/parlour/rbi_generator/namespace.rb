# typed: true
module Parlour
  class RbiGenerator
    class Namespace
      extend T::Sig

      include RbiObject

      sig { void }
      def initialize
        @children = []
      end

      sig { returns(T::Array[RbiObject]) }
      attr_reader :children
    end
  end
end