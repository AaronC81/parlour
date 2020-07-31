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

      sig { abstract.returns(String) }
      def generate_rbs; end

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

      sig { override.returns(String) }
      def generate_rbs
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

      sig { override.returns(String) }
      def generate_rbs
        "#{type.generate_rbs}?"
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

      sig { override.returns(String) }
      def generate_rbs
        "(#{types.map(&:generate_rbs).join(' | ')})"
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

      sig { override.returns(String) }
      def generate_rbs
        "(#{types.map(&:generate_rbs).join(' & ')})"
      end
    end

    class Tuple < Type
      sig { params(types: T::Array[TypeLike]).void }
      def initialize(types)
        @types = types.map(&method(:to_type))
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Tuple === other && types == other.types
      end

      sig { returns(T::Array[Type]) }
      attr_reader :types

      sig { override.returns(String) }
      def generate_rbi
        "[#{types.map(&:generate_rbi).join(', ')}]"
      end

      sig { override.returns(String) }
      def generate_rbs
        "[#{types.map(&:generate_rbs).join(', ')}]"
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

      sig { override.returns(String) }
      def generate_rbs
        "Array[#{element.generate_rbs}]"
      end
    end

    class Boolean < Type
      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Boolean === other
      end

      sig { override.returns(String) }
      def generate_rbi
        "T::Boolean"
      end

      sig { override.returns(String) }
      def generate_rbs
        "bool"
      end
    end

    class Untyped < Type
      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Untyped === other
      end

      sig { override.returns(String) }
      def generate_rbi
        "T.untyped"
      end

      sig { override.returns(String) }
      def generate_rbs
        "untyped"
      end
    end

    class Proc < Type
      sig { params(parameters: T::Array[RbiGenerator::Parameter], return_type: T.nilable(TypeLike)).void }
      def initialize(parameters, return_type)
        @parameters = parameters
        @return_type = return_type && to_type(return_type)
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Proc === other && parameters == other.parameters && return_type == other.return_type
      end

      sig { returns(T::Array[RbiGenerator::Parameter]) }
      attr_reader :parameters

      sig { returns(T.nilable(Type)) }
      attr_reader :return_type

      sig { override.returns(String) }
      def generate_rbi
        "T.proc.params(#{parameters.map(&:to_sig_param).join(', ')}).#{
          @return_type ? "returns(#{return_type.generate_rbi})" : 'void'
        }"
      end

      sig { override.returns(String) }
      def generate_rbs
        "(#{parameters.map(&:to_rbs_param).join(', ')}) -> #{return_type&.generate_rbs || 'void'}"
      end
    end
  end
end
        