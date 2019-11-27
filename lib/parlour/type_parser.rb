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

    #!!!!
    # TODO: Do we consider method definitions with sigs inside methods valid?
    #       How would this fit into the tree?
    # Also, class << self will be fun...
    # How do we handle methods WITHOUT sigs? I'm thinking default ignore, but
    # optionally generate arity-only sigs with T.untyped. Currently, this won't
    # find them at all.
    #!!!!

    sig { params(path: NodePath).returns(RbiGenerator::Method) }
    # Given a path to a sig in the AST, parses that sig into a method.
    # This will raise an exception if the sig is invalid.
    #
    # @param [NodePath] path The sig to parse.
    # @return [RbiGenerator::Method] The parsed method.
    def parse_sig(path)
      # TODO: error locs
      sig_block_node = path.traverse(ast)

      def_node = path.sibling(1).traverse(ast)
      raise 'node after a sig must be a method definition' unless def_node.type == :def
      def_name = def_node.to_a[0].to_s

      # A sig's AST uses lots of nested nodes due to a deep call chain, so let's
      # flatten it out to make it easier to work with
      sig_chain = []
      current_sig_chain_node = sig_block_node.to_a[2]
      while current_sig_chain_node
        _, name, *arguments = *current_sig_chain_node
        sig_chain << [name, arguments]
        current_sig_chain_node = current_sig_chain_node.to_a[0]
      end

      # Get basic boolean flags
      override =    !!sig_chain.find { |(n, a)| n == :override    && a.empty? }
      overridable = !!sig_chain.find { |(n, a)| n == :overridable && a.empty? }
      abstract =    !!sig_chain.find { |(n, a)| n == :abstract    && a.empty? }

      # TODO: final

      return_type = sig_chain
        .find { |(n, _)| n == :returns }
        &.then do |(_, a)|
          raise 'wrong number of arguments in "returns" for sig' if a.length != 1
          arg = a[0]
          exp = arg.loc.expression

          exp.source_buffer.source[exp.begin_pos...exp.end_pos]
        end

      def_args = def_node.to_a[1].to_a
      sig_args = sig_chain
        .find { |(n, _)| n == :params }
        &.then do |(_, a)|
          raise 'wrong number of arguments in "params" for sig' if a.length != 1
          arg = a[0]
          raise 'argument to "params" should be a hash' unless arg.type == :hash
          arg.to_a
        end

      raise 'mismatching number of arguments in sig and def' \
        if sig_args && def_args.length != sig_args.length

      # TODO: this is absolutely awful
      parameters = sig_args ? (def_args + sig_args)
        .group_by { |x| x.type == :pair ? x.to_a[0].to_a[0] : x.to_a[0] }
        .map do |name, value|
          raise "argument #{name} specified wrong number of times in sig or def" \
            unless value.length == 2
          sig_arg, def_arg = *(value.partition { |x| x.type == :pair }.flatten)

          # TODO: anonymous restarg
          full_name = name.to_s
          full_name = "*#{name}"  if def_arg.type == :restarg
          full_name = "**#{name}" if def_arg.type == :kwrestarg
          full_name = "#{name}:"  if def_arg.type == :kwarg || def_arg.type == :kwoptarg
          full_name = "&#{name}"  if def_arg.type == :blockarg

          default_exp = def_arg.to_a[1]&.loc&.expression
          default = default_exp \
            ? default_exp.source_buffer.source[default_exp.begin_pos...default_exp.end_pos]
            : nil

          type_exp = sig_arg.to_a[1].loc.expression
          type = type_exp.source_buffer.source[type_exp.begin_pos...type_exp.end_pos]

          RbiGenerator::Parameter.new(full_name, type: type, default: default)
        end : []

      RbiGenerator::Method.new(
        DetachedRbiGenerator.new,
        def_name,
        parameters,
        return_type,
        override: override,
        overridable: overridable,
        abstract: abstract,
      )
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