# typed: true
module Parlour
  class RbiGenerator
    class ClassNamespace < Namespace
      extend T::Sig

      sig { params(name: String, superclass: T.nilable(String)).void }
      def initialize(name, superclass)
        super
        @name = name
        @superclass = superclass
      end

      sig { returns(String) }
      attr_reader :name

      sig { returns(String) }
      attr_reader :superclass
    end
  end
end