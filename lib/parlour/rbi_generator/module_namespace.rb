# typed: true
module Parlour
  class RbiGenerator
    class ModuleNamespace < Namespace
      extend T::Sig

      sig do
        params(
          name: String,
          interface: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).void
      end
      def initialize(name, interface, &block)
        super(&block)
        @name = name
        @interface = interface
      end

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      def generate_rbi(indent_level, options)        
        lines = []
        lines << options.indented(indent_level, "module #{name}")
        lines += [options.indented(indent_level + 1, "interface!"), ""] if interface
        lines += super(indent_level + 1, options)
        lines << options.indented(indent_level, "end")
      end

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Boolean) }
      attr_reader :interface
    end
  end
end