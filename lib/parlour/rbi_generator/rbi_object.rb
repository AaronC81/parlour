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
          break_params: Integer,
          tab_size: Integer
        ).returns(String)
      end
      def generate_rbi(indent_level, break_params, tab_size); end
    end
  end
end