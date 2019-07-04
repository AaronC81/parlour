module Parlour
  class RbiGenerator
    class Options
      sig { params(break_params: Integer, tab_size: Integer).void }
      def initialize(break_params:, tab_size:)
        @break_params = break_params
        @tab_size = tab_size
      end
      
      sig { returns(Integer) }
      attr_reader :break_params

      sig { returns(Integer) }
      attr_reader :tab_size
    end
  end
end