# typed: true
module Parlour
  class RbiGenerator
    extend T::Sig

    sig { params(break_params: Integer, tab_size: Integer).void }
    def initialize(break_params: 4, tab_size: 2)
      @break_params = break_params
      @tab_size = tab_size
      @root = Namespace.new
    end

    sig { returns(Integer) }
    attr_reader :break_params

    sig { returns(Integer) }
    attr_reader :tab_size

    sig { returns(Namespace) }
    attr_reader :root
  end
end