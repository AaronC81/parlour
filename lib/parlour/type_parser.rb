# typed: ignore

# TODO: support sig without runtime

require 'parser/current'

module Parlour
  # Parses Ruby source to find Sorbet type signatures.
  class TypeParser
    # Represents a path of indeces which can be traversed to reach a specific
    # node in an AST.
    class NodePath
      extend T::Sig

      sig { returns(T::Array[Integer]) }
      # @return [Array<Integer>] The path of indeces.
      attr_reader :indeces

      sig { params(indeces: T::Array[Integer]).void }
      # Creates a new {NodePath}.
      #
      # @param [Array<Integer>] indeces The path of indeces.
      def initialize(indeces)
        @indeces = indeces
      end

      sig { returns(NodePath) }
      # @return [NodePath] The parent path for the node at this path.
      def parent
        if indeces.empty?
          raise IndexError, 'cannot get parent of an empty path'
        else
          NodePath.new(indeces[0...-1])
        end
      end

      sig { params(index: Integer).returns(NodePath) }
      # @param [Integer] index The index of the child whose path to return.
      # @return [NodePath] The path to the child at the given index.
      def child(index)
        NodePath.new(indeces + [index])
      end

      sig { params(offset: Integer).returns(NodePath) }
      # @param [Integer] offset The sibling offset to use. 0 is the current
      #   node, -1 is the previous node, or 3 is is the node three nodes after
      #   this one.
      # @return [NodePath] The path to the sibling with the given context.
      def sibling(offset)
        if indeces.empty?
          raise IndexError, 'cannot get sibling of an empty path'
        else
          *xs, x = indeces
          raise ArgumentError, "sibling offset of #{offset} results in " \
            "negative index of #{x + offset}" if x + offset < 0
          NodePath.new(xs + [x + offset])
        end
      end

      sig { params(start: Parser::AST::Node).returns(Parser::AST::Node) }
      # Follows this path of indeces from an AST node.
      #
      # @param [Parser::AST::Node] start The AST node to start from.
      # @return [Parser::AST::Node] The resulting AST node.
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
    # Creates a new {TypeParser} from whitequark/parser AST.
    #
    # @param [Parser::AST::Node] The AST.
    def initialize(ast)
      @ast = ast
    end

    sig { params(filename: String, source: String).returns(TypeParser) }
    # Creates a new {TypeParser} from a source file and its filename.
    #
    # @param [String] filename A filename. This does not need to be an actual
    #   file; it merely identifies this source.
    # @param [String] source The Ruby source code.
    # @return [TypeParser]
    def self.from_source(filename, source)
      buffer = Parser::Source::Buffer.new(filename)
      buffer.source = source
      
      TypeParser.new(Parser::CurrentRuby.new.parse(buffer))
    end

    sig { returns(Parser::AST::Node) }
    # @return [Parser::AST::Node] The AST which this type parser should use.
    attr_accessor :ast

    sig { returns(T::Array[NodePath]) }
    # Finds ALL uses of sig in the AST, including those which are not 
    # semantically valid as Sorbet signatures.
    #
    # Specifically, this searches the entire AST for any calls of a
    # method called "sig" which pass a block.
    #
    # @return [Array<NodePath>] The node paths to the signatures.
    def find_sigs
      find_sigs_at(ast, NodePath.new([]))
    end

    protected

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
