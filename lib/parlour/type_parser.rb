# typed: ignore

# TODO: support sig without runtime

require 'parser/current'

module Parlour
  class TypeParser
    class NodePath < T::Struct
      extend T::Sig

      prop :indeces, T::Array[Integer]

      sig { returns(NodePath) }
      def parent
        if indeces.empty?
          raise IndexError, 'cannot get parent of an empty path'
        else
          NodePath.new(indeces: indeces[0...-1])
        end
      end

      sig { params(index: Integer).returns(NodePath) }
      def child(index)
        NodePath.new(indeces: indeces + [index])
      end

      sig { params(start: Parser::AST::Node).returns(Parser::AST::Node) }
      def traverse(start)
        current = start
        indeces.each do |index|
          current = current.to_a[index]
        end
        current
      end
    end

    extend T::Sig

    sig { params(ast: Parser::AST::Node).void }
    def initialize(ast)
      @ast = ast
    end

    sig { params(filename: String, source: String).returns(TypeParser) }
    def self.from_source(filename, source)
      buffer = Parser::Source::Buffer.new(filename)
      buffer.source = source
      
      TypeParser.new(Parser::CurrentRuby.new.parse(buffer))
    end

    sig { returns(Parser::Source::Buffer) }
    attr_accessor :buffer

    sig { returns(Parser::AST::Node) }
    attr_accessor :ast

    sig { returns(T::Array[NodePath]) }
    def find_sigs
      find_sigs_at(ast, NodePath.new(indeces: []))
    end

    sig { params(node: Parser::AST::Node, path: NodePath).returns(T::Array[NodePath]) }
    def find_sigs_at(node, path)
      types_in_this_node = node.to_a.map.with_index do |child, i|
        child.is_a?(Parser::AST::Node) &&
          child.type == :block &&
          child.to_a[0].type == :send &&
          child.to_a[0].to_a[1] == :sig \
          ? path.child(i) : nil
      end.compact
      
      types_in_children = node.to_a
        .select { |child| child.is_a?(Parser::AST::Node) }
        .map.with_index { |child, i| find_sigs_at(child, path.child(i)) }
        .flatten

      types_in_this_node + types_in_children
    end
  end
end
