# typed: true
module Parlour
  module Conversion
    # An abstract class which converts between the node trees of two type
    # systems.
    class Converter
      extend T::Sig
      extend T::Helpers
      abstract!

      def initialize
        @warnings = []
      end

      sig { returns(T::Array[[String, TypedObject]]) }
      attr_reader :warnings

      def add_warning(msg, node)
        warnings << [msg, node]
      end
    end
  end
end