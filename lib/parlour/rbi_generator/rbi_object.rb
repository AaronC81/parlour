# typed: true
module Parlour
  class RbiGenerator
    module RbiObject
      extend T::Helpers
      extend T::Sig
      interface!

      sig do
        abstract.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_rbi(indent_level, options); end
    end
  end
end