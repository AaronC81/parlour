# typed: true

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
          NodePath.new(T.must(indeces[0...-1]))
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
          x = T.must(x)
          raise ArgumentError, "sibling offset of #{offset} results in " \
            "negative index of #{x + offset}" if x + offset < 0
          NodePath.new(T.must(xs) + [x + offset])
        end
      end

      sig { params(start: Parser::AST::Node).returns(Parser::AST::Node) }
      # Follows this path of indeces from an AST node.
      #
      # @param [Parser::AST::Node] start The AST node to start from.
      # @return [Parser::AST::Node] The resulting AST node.
      def traverse(start)
        current = T.unsafe(start)
        indeces.each do |index|
          raise IndexError, 'path does not exist' if index >= current.to_a.length
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

    # Parses the entire source file and returns the resulting root namespace.
    #
    # @return [RbiGenerator::Namespace] The root namespace of the parsed source.
    sig { returns(RbiGenerator::Namespace) }
    def parse_all
      root = RbiGenerator::Namespace.new(DetachedRbiGenerator.new)
      root.children.concat(parse_path_to_object(NodePath.new([])))
      root
    end

    # Given a path to a node in the AST, parses the object definitions it
    # represents and returns it, recursing to any child namespaces and parsing
    # any methods within.
    #
    # If the node directly represents several nodes, such as being a 
    # (begin ...) node, they are all returned.
    #
    # @param [NodePath] path The path to the namespace definition.
    # @return [Array<RbiGenerator::RbiObject>] The objects the node at the path
    #    represents, parsed into an RBI generator object.
    sig { params(path: NodePath).returns(T::Array[RbiGenerator::RbiObject]) }
    def parse_path_to_object(path)
      node = path.traverse(ast)

      # TODO: elegantly handle namespace names like A::B::C
      # Probably create the upper ones iteratively, then proceed to operate on
      # the final one
      
      case node.type
      when :class
        name, superclass, body = *node
        final = body_has_modifier?(body, :final!)
        abstract = body_has_modifier?(body, :abstract!)
        includes, extends = body ? body_includes_and_extends(body) : [[], []]

        [RbiGenerator::ClassNamespace.new(
          DetachedRbiGenerator.new,
          T.must(node_to_s(name)),
          final,
          node_to_s(superclass),
          abstract,
        ) do |c|
          c.children.concat(parse_path_to_object(path.child(2))) if body
          c.create_includes(includes)
          c.create_extends(extends)
        end]
      when :module
        name, body = *node
        final = body_has_modifier?(body, :final!)
        interface = body_has_modifier?(body, :interface!)
        includes, extends = body ? body_includes_and_extends(body) : [[], []]

        [RbiGenerator::ModuleNamespace.new(
          DetachedRbiGenerator.new,
          T.must(node_to_s(name)),
          final,
          interface,
        ) do |m|
          m.children.concat(parse_path_to_object(path.child(1))) if body
          m.create_includes(includes)
          m.create_extends(extends)
        end]
      when :send, :block
        if sig_node?(node)
          [parse_sig(path)]
        else
          # TODO: handle attr_accessor, or if we don't recognise it we can 
          # probably just ignore it
          []
        end
      when :def
        # TODO:
        # Do we want to include defs if they don't have a sig?
        #   If so, we need some kind of state machine to determine whether
        #   they've already been dealt with by the "when :send" clause and 
        #   #parse_sig.
        #   If not, just ignore this.
        []
      when :begin
        # Just map over all the things
        node.to_a.length.times.map { |c| parse_path_to_object(path.child(c)) }.flatten
      else
        raise "don't understand node type #{node.type}"
      end
    end

    sig { params(path: NodePath, is_within_eigen: T::Boolean).returns(RbiGenerator::Method) }
    # Given a path to a sig in the AST, parses that sig into a method.
    # This will raise an exception if the sig is invalid.
    #
    # @param [NodePath] path The sig to parse.
    # @param [Boolean] is_within_eigen Whether the method definition this sig is
    #   associated with appears inside an eigenclass definition. If true, the
    #   returned method is made a class method. If the method definition
    #   is already a class method, an exception is thrown as the method will be
    #   a class method of the eigenclass, which Parlour can't represent.
    # @return [RbiGenerator::Method] The parsed method.
    def parse_sig(path, is_within_eigen: false)
      # TODO: error locs
      sig_block_node = path.traverse(ast)

      # A :def node represents a definition like "def x; end"
      # A :defs node represents a definition like "def self.x; end"
      def_node = path.sibling(1).traverse(ast)
      case def_node.type
      when :def
        class_method = false
        def_name = def_node.to_a[0].to_s
        def_args = def_node.to_a[1].to_a
      when :defs
        raise 'targeted definitions on a non-self target are not supported' \
          unless def_node.to_a[0].type == :self
        class_method = true
        def_name = def_node.to_a[1].to_s
        def_args = def_node.to_a[2].to_a
      else
        raise 'node after a sig must be a method definition'
      end

      if is_within_eigen
        raise 'cannot represent multiple levels of eigenclassing' if class_method
        class_method = true
      end

      # A sig's AST uses lots of nested nodes due to a deep call chain, so let's
      # flatten it out to make it easier to work with
      sig_chain = []
      current_sig_chain_node = sig_block_node.to_a[2]
      while current_sig_chain_node
        name = current_sig_chain_node.to_a[1]
        arguments = current_sig_chain_node.to_a[2..-1]

        sig_chain << [name, arguments]
        current_sig_chain_node = current_sig_chain_node.to_a[0]
      end

      # Get basic boolean flags
      override =    !!sig_chain.find { |(n, a)| n == :override    && a.empty? }
      overridable = !!sig_chain.find { |(n, a)| n == :overridable && a.empty? }
      abstract =    !!sig_chain.find { |(n, a)| n == :abstract    && a.empty? }

      # Determine whether this method is final (i.e. sig(:final))
      _, _, *sig_arguments = *sig_block_node.to_a[0]
      final = sig_arguments.any? { |a| a.type == :sym && a.to_a[0] == :final }

      return_type = sig_chain
        .find { |(n, _)| n == :returns }
        &.then do |(_, a)|
          raise 'wrong number of arguments in "returns" for sig' if a.length != 1
          arg = a[0]
          exp = arg.loc.expression

          exp.source_buffer.source[exp.begin_pos...exp.end_pos]
        end

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
        final: final,
        class_method: class_method
      )
    end
    
    protected

    sig { params(node: Parser::AST::Node).returns(T::Boolean) }
    # Given a node, returns a boolean indicating whether that node represents a
    # a call to "sig" with a block. No further semantic checking, such as
    # whether it preceeds a method call, is done.
    #
    # @param [Parser::AST::Node] node The node to check.
    # @return [Boolean] True if that node represents a "sig" call, false
    #   otherwise.
    def sig_node?(node)
      node.type == :block &&
        node.to_a[0].type == :send &&
        node.to_a[0].to_a[1] == :sig
    end

    sig { params(node: T.nilable(Parser::AST::Node)).returns(T.nilable(String)) }
    # Given an AST node, returns the source code from which it was constructed.
    # If the given AST node is nil, this returns nil.
    #
    # @param [Parser::AST::Node, nil] node The AST node, or nil.
    # @return [String] The source code string it represents, or nil.
    def node_to_s(node)
      return nil unless node

      exp = T.unsafe(node).loc.expression
      exp.source_buffer.source[exp.begin_pos...exp.end_pos]
    end

    sig { params(node: T.nilable(Parser::AST::Node), modifier: Symbol).returns(T::Boolean) }
    # Given an AST node and a symbol, determines if that node is a call (or a
    # body containing a call at the top level) to the method represented by the
    # symbol, without any arguments or a block.
    #
    # This is designed to be used to determine if a namespace body uses a Sorbet
    # modifier such as "abstract!".
    #
    # @param [Parser::AST::Node, nil] node The AST node to search in.
    # @param [Symbol] modifier The method name to search for.
    # @return [T::Boolean] True if the call is found, or false otherwise.
    def body_has_modifier?(node, modifier)
      return false unless node

      (node.type == :send && node.to_a == [nil, modifier]) || 
        (node.type == :begin &&
          node.to_a.any? { |c| c.type == :send && c.to_a == [nil, modifier] })
    end

    sig { params(node: Parser::AST::Node).returns([T::Array[String], T::Array[String]]) }
    # Given an AST node representing the body of a class or module, returns two 
    # arrays of the includes and extends contained within the body.
    #
    # @param [Parser::AST::Node] node The body of the namespace.
    # @return [(Array<String>, Array<String>)] An array of the includes and an
    #   array of the extends.
    def body_includes_and_extends(node)
      result = [[], []]

      nodes_to_search = node.type == :begin ? node.to_a : [node]
      nodes_to_search.each do |this_node|
        next unless this_node.type == :send
        target, name, *args = *this_node
        next unless target.nil? && args.length == 1

        if name == :include
          result[0] << node_to_s(args.first)
        elsif name == :extend
          result[1] << node_to_s(args.first)
        end
      end

      result
    end
  end
end