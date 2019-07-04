# typed: true
module Parlour
  class RbiGenerator
    class ClassNamespace < Namespace
      extend T::Sig

      sig { params(name: String, superclass: T.nilable(String), abstract: T::Boolean).void }
      def initialize(name, superclass, abstract)
        super
        @name = name
        @superclass = superclass
        @abstract = abstract
      end

      sig { returns(String) }
      attr_reader :name

      sig { returns(String) }
      attr_reader :superclass

      sig { returns(T::Boolean) }
      attr_reader :abstract
    end
  end
end