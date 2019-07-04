# typed: true
module Parlour
  class RbiGenerator
    class Method
      extend T::Sig

      include RbiObject

      sig do
        params(
          name: String,
          parameters: T::Array[Parameter],
          return_type: T.nilable(String),
          abstract: T::Boolean,
          implementation: T::Boolean,
          override: T::Boolean,
          overridable: T::Boolean
        ).void
      end
      def initialize(name, parameters, return_type = nil, abstract: false, implementation: false, override: false, overridable: false)
        @name = name
        @parameters = parameters
        @return_type = return_type
        @abstract = abstract
        @implementation = implementation
        @override = override
        @overridable = overridable
      end

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[Parameter]) }
      attr_reader :parameters

      sig { returns(T.nilable(String)) }
      attr_reader :return_type

      sig { returns(T::Boolean) }
      attr_reader :abstract

      sig { returns(T::Boolean) }
      attr_reader :implementation

      sig { returns(T::Boolean) }
      attr_reader :override

      sig { returns(T::Boolean) }
      attr_reader :overridable

      sig do
        implementation.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_rbi(indent_level, options)
        return_call = return_type ? "returns(#{return_type})" : 'void'

        sig_params = parameters.map(&:to_sig_param)
        sig_lines = parameters.length >= options.break_params \
          ? [
              options.indented(indent_level, 'sig do'),
              options.indented(indent_level + 1, "#{qualifiers}params("),
            ] +
            (
              parameters.empty? ? [] : sig_params.map do |x|
                options.indented(indent_level + 2, "#{x},") 
              end
            ) +
            [
              options.indented(indent_level + 1, ").#{return_call}"),
              options.indented(indent_level, 'end')
            ]

          : [options.indented(
              indent_level,
              "sig { #{qualifiers}#{
                parameters.empty? ? '' : "params(#{sig_params.join(', ')})"
              }#{
                qualifiers.empty? && parameters.empty? ? '' : '.'
              }#{return_call} }"
            )]

        def_params = parameters.map(&:to_def_param)
        def_line = "def #{name}(#{def_params.join(', ')}); end"

        sig_lines + [def_line]
      end

      sig { returns(String) }
      def qualifiers
        result = ''
        result += 'abstract.' if abstract
        result += 'implementation.' if implementation
        result += 'override.' if override
        result += 'overridable.' if overridable
        result
      end
    end
  end
end