# typed: true

module Parlour
  # Contains structured types which can be used in type signatures.
  module Types
    TypeLike = T.type_alias { T.any(String, Type) }

    class Type
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { abstract.returns(String) }
      def generate_rbi; end

      sig { params(type_like: TypeLike).returns(Type) }
      def to_type(type_like)
        if type_like.is_a?(String)
          Raw.new(type_like)
        else
          type_like
        end
      end
    end

    class Raw < Type
      sig { params(str: String).void }
      def initialize(str)
        @str = str
      end

      sig { returns(String) }
      attr_reader :str

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Raw === other && str == other.str
      end

      sig { override.returns(String) }
      def generate_rbi
        str
      end
    end

    class Nilable < Type
      sig { params(type: TypeLike).void }
      def initialize(type)
        @type = to_type(type)
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Nilable === other && type == other.type
      end

      sig { returns(Type) }
      attr_reader :type

      sig { override.returns(String) }
      def generate_rbi
        "T.nilable(#{type.generate_rbi})"
      end
    end

    class Union < Type
      sig { params(types: T::Array[TypeLike]).void }
      def initialize(types)
        @types = types.map(&method(:to_type))
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Union === other && types == other.types
      end

      sig { returns(T::Array[Type]) }
      attr_reader :types

      sig { override.returns(String) }
      def generate_rbi
        "T.any(#{types.map(&:generate_rbi).join(', ')})"
      end
    end

    class Intersection < Type
      sig { params(types: T::Array[TypeLike]).void }
      def initialize(types)
        @types = types.map(&method(:to_type))
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Intersection === other && types == other.types
      end

      sig { returns(T::Array[Type]) }
      attr_reader :types

      sig { override.returns(String) }
      def generate_rbi
        "T.all(#{types.map(&:generate_rbi).join(', ')})"
      end
    end

    class Array < Type
      sig { params(element: TypeLike).void }
      def initialize(element)
        @element = to_type(element)
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Array === other && element == other.element
      end

      sig { returns(Type) }
      attr_reader :element

      sig { override.returns(String) }
      def generate_rbi
        "T::Array[#{element.generate_rbi}]"
      end
    end
  end
end
        