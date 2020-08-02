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
      def self.to_type(type_like)
        if type_like.is_a?(String)
          Raw.new(type_like)
        else
          type_like
        end
      end

      sig { params(type_like: TypeLike).returns(Type) }
      def to_type(type_like)
        Type.to_type(type_like)
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

    class SingleElementCollection < Type
      abstract!

      sig { params(element: TypeLike).void }
      def initialize(element)
        @element = to_type(element)
      end

      sig { returns(Type) }
      attr_reader :element

      sig { abstract.returns(String) }
      def collection_name; end

      sig { override.returns(String) }
      def generate_rbi
        "T::#{collection_name}[#{element.generate_rbi}]"
      end

      sig { override.returns(String) }
      def generate_rbs
        "#{collection_name}[#{element.generate_rbs}]"
      end
    end

    class Array < SingleElementCollection
      sig { override.returns(String) }
      def collection_name
        'Array'
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Array === other && element == other.element
      end
    end

    class Set < SingleElementCollection
      sig { override.returns(String) }
      def collection_name
        'Set'
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Set === other && element == other.element
      end
    end

    class Range < SingleElementCollection
      sig { override.returns(String) }
      def collection_name
        'Range'
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Range === other && element == other.element
      end
    end

    class Enumerable < SingleElementCollection
      sig { override.returns(String) }
      def collection_name
        'Enumerable'
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Enumerable === other && element == other.element
      end
    end

    class Enumerator < SingleElementCollection
      sig { override.returns(String) }
      def collection_name
        'Enumerator'
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Enumerator === other && element == other.element
      end
    end

    class Hash < Type
      sig { params(key: TypeLike, value: TypeLike).void }
      def initialize(key, value)
        @key = to_type(key)
        @value = to_type(value)
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Hash === other && key == other.key && value == other.value
      end

      sig { returns(Type) }
      attr_reader :key

      sig { returns(Type) }
      attr_reader :value

      sig { override.returns(String) }
      def generate_rbi
        "T::Hash[#{key.generate_rbi}, #{value.generate_rbi}]"
      end

      sig { override.returns(String) }
      def generate_rbs
        "Hash[#{key.generate_rbs}, #{value.generate_rbs}]"
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
      class Parameter
        extend T::Sig

        sig { params(name: String, type: TypeLike, default: T.nilable(String)).void }
        def initialize(name, type, default = nil)
          @name = name
          @type = Type.to_type(type)
          @default = default
        end

        sig { returns(String) }
        attr_reader :name

        sig { returns(Type) }
        attr_reader :type

        sig { returns(T.nilable(String)) }
        attr_reader :default

        sig { params(other: Object).returns(T::Boolean) }
        def ==(other)
          Parameter === other && name == other.name && type == other.type &&
            default == other.default
        end  
      end
      
      sig { params(parameters: T::Array[Parameter], return_type: T.nilable(TypeLike)).void }
      def initialize(parameters, return_type)
        @parameters = parameters
        @return_type = return_type && to_type(return_type)
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Proc === other && parameters == other.parameters && return_type == other.return_type
      end

      sig { returns(T::Array[Parameter]) }
      attr_reader :parameters

      sig { returns(T.nilable(Type)) }
      attr_reader :return_type

      sig { override.returns(String) }
      def generate_rbi
        rbi_params = parameters.map do |param|
          RbiGenerator::Parameter.new(param.name, type: param.type, default: param.default)
        end
        "T.proc.params(#{rbi_params.map(&:to_sig_param).join(', ')}).#{
          @return_type ? "returns(#{@return_type.generate_rbi})" : 'void'
        }"
      end

      sig { override.returns(String) }
      def generate_rbs
        rbs_params = parameters.map do |param|
          RbsGenerator::Parameter.new(param.name, type: param.type, required: param.default.nil?)
        end
        "(#{rbs_params.map(&:to_rbs_param).join(', ')}) -> #{return_type&.generate_rbs || 'void'}"
      end
    end
  end
end
        