# typed: true
module Parlour
  class RbiGenerator
    class Parameter
      extend T::Sig

      sig do
        params(
          name: String,
          type: T.nilable(String),
          default: T.nilable(String)
        ).void
      end
      def initialize(name, type: nil, default: nil)
        @name = name

        prefix = /^(\*\*|\*|\&)?/.match(name)&.captures&.first || ''
        @kind = PREFIXES.rassoc(prefix).first

        @kind = :keyword if kind == :normal && name.end_with?(':')

        @type = type
        @default = default
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        Parameter === other &&
          name    == other.name &&
          kind    == other.kind &&
          type    == other.type &&
          default == other.default
      end

      sig { returns(String) }
      attr_reader :name

      sig { returns(String) }
      def name_without_kind
        return T.must(name[0..-2]) if kind == :keyword

        prefix_match = /^(\*\*|\*|\&)?[a-zA-Z_]/.match(name)
        raise 'unknown prefix' unless prefix_match
        prefix = prefix_match.captures.first || ''
        T.must(name[prefix.length..-1])
      end

      sig { returns(T.nilable(String)) }
      attr_reader :type

      sig { returns(T.nilable(String)) }
      attr_reader :default

      sig { returns(Symbol) }
      attr_reader :kind

      sig { returns(String) }
      def to_def_param
        if default.nil?
          "#{name}"
        elsif !default.nil? && kind == :keyword
          "#{name} #{default}"
        else
          "#{name} = #{default}"
        end
      end

      sig { returns(String) }
      def to_sig_param
        "#{name_without_kind}: #{type || 'T.untyped'}"
      end

      PREFIXES = {
        normal: '',
        splat: '*',
        double_splat: '**',
        block: '&'
      }.freeze
    end
  end
end
