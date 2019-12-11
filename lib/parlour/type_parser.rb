# typed: true

# TODO: support sig without runtime

# Suppress versioning warnings - the majority of users will not actually be
# using this, so we don't want to pollute their console
old_verbose = $VERBOSE
begin
  $VERBOSE = nil
  require 'parser/current'
ensure
  $VERBOSE = old_verbose
end

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

    sig { params(ast: Parser::AST::Node, unknown_node_errors: T::Boolean).void }
    # Creates a new {TypeParser} from whitequark/parser AST.
    #
    # @param [Parser::AST::Node] The AST.
    # @param [Boolean] unknown_node_errors Whether to raise an error if a node
    #   of an unknown kind is encountered. If false, the node is simply ignored;
    #   if true, a parse error is raised. Setting this to true is likely to
    #   raise errors for lots of non-RBI Ruby code, but setting it to false
    #   could miss genuine typed objects if Parlour or your code contains a bug.
    def initialize(ast, unknown_node_errors: false)
      @ast = ast
      @unknown_node_errors = unknown_node_errors
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

    sig { returns(T::Boolean) }
    # @return [Boolean] Whether to raise an error if a node of an unknown kind
    #   is encountered. 
    attr_reader :unknown_node_errors

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
    # @param [NodePath] path The path to the namespace definition. Do not pass
    #   any of the other parameters to this method in an external call.
    # @return [Array<RbiGenerator::RbiObject>] The objects the node at the path
    #    represents, parsed into an RBI generator object.
    sig { params(path: NodePath, is_within_eigen: T::Boolean).returns(T::Array[RbiGenerator::RbiObject]) }
    def parse_path_to_object(path, is_within_eigen: false)
      node = path.traverse(ast)
      
      case node.type
      when :class
        parse_err 'cannot declare classes in an eigenclass', node if is_within_eigen

        name, superclass, body = *node
        final = body_has_modifier?(body, :final!)
        abstract = body_has_modifier?(body, :abstract!)
        includes, extends = body ? body_includes_and_extends(body) : [[], []]

        # Create all classes, if we're given a definition like "class A::B"
        *parent_names, this_name = constant_names(name)
        target = T.let(nil, T.nilable(RbiGenerator::Namespace))
        top_level = T.let(nil, T.nilable(RbiGenerator::Namespace))
        parent_names.each do |n| 
          new_obj = RbiGenerator::Namespace.new(
            DetachedRbiGenerator.new,
            n.to_s,
            false,
          )
          target.children << new_obj if target
          target = new_obj
          top_level ||= new_obj
        end if parent_names

        final_obj = RbiGenerator::ClassNamespace.new(
          DetachedRbiGenerator.new,
          this_name.to_s,
          final,
          node_to_s(superclass),
          abstract,
        ) do |c|
          c.children.concat(parse_path_to_object(path.child(2))) if body
          c.create_includes(includes)
          c.create_extends(extends)
        end

        if target
          target.children << final_obj
          [top_level]
        else
          [final_obj]
        end
      when :module
        parse_err 'cannot declare modules in an eigenclass', node if is_within_eigen

        name, body = *node
        final = body_has_modifier?(body, :final!)
        interface = body_has_modifier?(body, :interface!)
        includes, extends = body ? body_includes_and_extends(body) : [[], []]

        # Create all modules, if we're given a definition like "module A::B"
        *parent_names, this_name = constant_names(name)
        target = T.let(nil, T.nilable(RbiGenerator::Namespace))
        top_level = T.let(nil, T.nilable(RbiGenerator::Namespace))
        parent_names.each do |n| 
          new_obj = RbiGenerator::Namespace.new(
            DetachedRbiGenerator.new,
            n.to_s,
            false,
          )
          target.children << new_obj if target
          target = new_obj
          top_level ||= new_obj
        end if parent_names

        final_obj = RbiGenerator::ModuleNamespace.new(
          DetachedRbiGenerator.new,
          this_name.to_s,
          final,
          interface,
        ) do |m|
          m.children.concat(parse_path_to_object(path.child(1))) if body
          m.create_includes(includes)
          m.create_extends(extends)
        end

        if target
          target.children << final_obj
          [top_level]
        else
          [final_obj]
        end
      when :send, :block
        if sig_node?(node)
          [parse_sig(path, is_within_eigen: is_within_eigen)]
        else
          []
        end
      when :def, :defs
        # TODO: Support for defs without sigs
        #   If so, we need some kind of state machine to determine whether
        #   they've already been dealt with by the "when :send" clause and 
        #   #parse_sig.
        #   If not, just ignore this.
        []
      when :sclass
        parse_err 'cannot access eigen of non-self object', node unless node.to_a[0].type == :self
        parse_path_to_object(path.child(1), is_within_eigen: true)
      when :begin
        # Just map over all the things
        node.to_a.length.times.map do |c|
          parse_path_to_object(path.child(c), is_within_eigen: is_within_eigen) 
        end.flatten
      else
        if unknown_node_errors
          parse_err "don't understand node type #{node.type}", node
        else
          []
        end
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
      sig_block_node = path.traverse(ast)

      # A :def node represents a definition like "def x; end"
      # A :defs node represents a definition like "def self.x; end"
      def_node = path.sibling(1).traverse(ast)
      case def_node.type
      when :def
        class_method = false
        def_name = def_node.to_a[0].to_s
        def_args = def_node.to_a[1].to_a
        kind = :def
      when :defs
        parse_err 'targeted definitions on a non-self target are not supported', def_node \
          unless def_node.to_a[0].type == :self
        class_method = true
        def_name = def_node.to_a[1].to_s
        def_args = def_node.to_a[2].to_a
        kind = :def
      when :send
        target, method_name, *parameters = *def_node

        parse_err 'node after a sig must be a method definition', def_node \
          unless [:attr_reader, :attr_writer, :attr_accessor].include?(method_name) \
            || target != nil

        # TODO: this is incorrect, Sorbet handles this fine; so this method 
        # needs to be refactored so that it can return multiple methods!!
        parse_err 'typed attribute should only have one name', def_node unless parameters&.length == 1
        
        kind = :attr
        attr_direction = method_name.to_s.gsub('attr_', '').to_sym
        def_name = parameters.to_a[0].to_a[0].to_s
        class_method = false
      else
        parse_err 'node after a sig must be a method definition', def_node
      end

      if is_within_eigen
        parse_err 'cannot represent multiple levels of eigenclassing', def_node if class_method
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

      # Find the return type by looking for a "returns" call
      return_type = sig_chain
        .find { |(n, _)| n == :returns }
        &.then do |(_, a)|
          parse_err 'wrong number of arguments in "returns" for sig', sig_block_node if a.length != 1
          node_to_s(a[0])
        end

      # Find the arguments specified in the "params" call in the sig
      sig_args = sig_chain
        .find { |(n, _)| n == :params }
        &.then do |(_, a)|
          parse_err 'wrong number of arguments in "params" for sig', sig_block_node if a.length != 1
          arg = a[0]
          parse_err 'argument to "params" should be a hash', arg unless arg.type == :hash
          arg.to_a
        end

      if kind == :def
        parse_err 'mismatching number of arguments in sig and def', sig_block_node \
          if sig_args && def_args.length != sig_args.length

        # sig_args will look like:
        #   [(pair (sym :x) <type>), (pair (sym :y) <type>), ...]
        # def_args will look like:
        #   [(arg :x), (arg :y), ...]
        parameters = sig_args \
          ? zip_by(sig_args, ->x{ x.to_a[0].to_a[0] }, def_args, ->x{ x.to_a[0] })
            .map do |sig_arg, def_arg|
              arg_name = def_arg.to_a[0]

              # TODO: anonymous restarg
              full_name = arg_name.to_s
              full_name = "*#{arg_name}"  if def_arg.type == :restarg
              full_name = "**#{arg_name}" if def_arg.type == :kwrestarg
              full_name = "#{arg_name}:"  if def_arg.type == :kwarg || def_arg.type == :kwoptarg
              full_name = "&#{arg_name}"  if def_arg.type == :blockarg

              default = def_arg.to_a[1] ? node_to_s(def_arg.to_a[1]) : nil
              type = node_to_s(sig_arg.to_a[1])

              RbiGenerator::Parameter.new(full_name, type: type, default: default)
            end
          : []

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
      elsif kind == :attr
        case attr_direction
        when :reader, :accessor
          parse_err "attr_#{attr_direction} sig should have no parameters", sig_block_node \
            if sig_args && sig_args.length > 0

          parse_err "attr_#{attr_direction} sig should have non-void return", sig_block_node \
            if return_type.nil?
            
          attr_type = return_type
        when :writer
          parse_err "attr_writer sig should take one argument with the property's name", sig_block_node \
            if sig_args.length != 1 || sig_args[0].to_a[0].to_a[0].to_s != def_name

          parse_err "attr_writer sig should have non-void return", sig_block_node \
            if return_type.nil?

          attr_type = T.must(node_to_s(sig_args[0].to_a[1]))
        else
          raise "unknown attribute direction #{attr_direction}"
        end

        RbiGenerator::Attribute.new(
          DetachedRbiGenerator.new,
          def_name,
          attr_direction,
          attr_type,
          class_attribute: class_method
        )
      else
        raise "unknown definition kind #{kind}"
      end
    end

    protected

    sig { params(node: T.nilable(Parser::AST::Node)).returns(T::Array[Symbol]) }
    # Given a node representing a simple chain of constants (such as A or
    # A::B::C), converts that node into an array of the constant names which
    # are accessed. For example, A::B::C would become [:A, :B, :C].
    #
    # @param [Parser::AST::Node, nil] node The node to convert. This must 
    #   consist only of nested (:const) nodes.
    # @return [Array<Symbol>] The chain of constant names.
    def constant_names(node)
      node ? constant_names(node.to_a[0]) + [node.to_a[1]] : []
    end

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

    sig { params(desc: String, node: T.any(Parser::AST::Node, NodePath)).returns(T.noreturn) }
    # Raises a parse error on a node.
    # @param [String] desc A description of the error.
    # @param [Parser::AST::Node, NodePath] A node, passed as either a path or a
    #   raw parser node.
    def parse_err(desc, node)
      node = node.traverse(ast) if node.is_a?(NodePath)
      range = node.loc.expression
      buffer = range.source_buffer

      raise ParseError.new(buffer, range), desc
    end

    sig do 
      type_parameters(:A, :B)
        .params(
          a: T::Array[T.type_parameter(:A)],
          fa: T.proc.params(item: T.type_parameter(:A)).returns(T.untyped),
          b: T::Array[T.type_parameter(:B)],
          fb: T.proc.params(item: T.type_parameter(:B)).returns(T.untyped)
        )
        .returns(T::Array[[T.type_parameter(:A), T.type_parameter(:B)]])
    end
    # Given two arrays and functions to get a key for each item in the two
    # arrays, joins the two arrays into one array of pairs by that key.
    # 
    # The arrays should both be the same length, and the key functions should
    # never return duplicate keys for two different items.
    #
    # @param [Array<A>] a The first array.
    # @param [A -> Any] fa A function to obtain a key for any element in the
    #   first array.
    # @param [Array<B>] b The second array.
    # @param [B -> Any] fb A function to obtain a key for any element in the 
    #   second array.
    # @return [Array<(A, B)>] An array of pairs, where the left of the pair is
    #   an element from A and the right is the element from B with the
    #   corresponding key.
    def zip_by(a, fa, b, fb)
      raise ArgumentError, "arrays are not the same length" if a.length != b.length

      a.map do |a_item|
        a_key = fa.(a_item)
        b_items = b.select { |b_item| fb.(b_item) == a_key }
        raise "multiple items for key #{a_key}" if b_items.length > 1
        raise "no item in second list corresponding to key #{a_key}" if b_items.length == 0

        [a_item, T.must(b_items[0])]
      end
    end
  end
end