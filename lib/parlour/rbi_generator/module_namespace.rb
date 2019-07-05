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

      sig do
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).returns(T::Boolean)
      end
      def mergeable?(others)
        others = T.cast(others, T::Array[RbiGenerator::ModuleNamespace]) rescue (return false)
        all = others + [self]

        all.map(&:interface).uniq.length == 1
      end

      sig do 
        override.params(
          others: T::Array[RbiGenerator::RbiObject]
        ).void
      end
      def merge_into_self(others)
        others.each do |other|
          other = T.cast(other, ModuleNamespace)

          other.children.each { |c| children << c }
          other.extends.each { |e| extends << e }
          other.includes.each { |i| includes << i }
        end
      end
    end
  end
end