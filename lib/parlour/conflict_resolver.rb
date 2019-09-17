# typed: true
module Parlour
  # Responsible for resolving conflicts (that is, multiple definitions with the
  # same name) between objects defined in the same namespace.
  class ConflictResolver
    extend T::Sig

    sig do
      params(
        namespace: RbiGenerator::Namespace,
        resolver: T.proc.params(
          desc: String,
          choices: T::Array[RbiGenerator::RbiObject]
        ).returns(RbiGenerator::RbiObject)
      ).void
    end
    # Given a namespace, attempts to automatically resolve conflicts in the
    # namespace's definitions. (A conflict occurs when multiple objects share
    # the same name.)
    #
    # All children of the given namespace which are also namespaces are
    # processed recursively, so passing {RbiGenerator#root} will eliminate all
    # conflicts in the entire object tree.
    # 
    # If automatic resolution is not possible, the block passed to this method
    # is invoked and passed two arguments: a message on what the conflict is,
    # and an array of candidate objects. The block should return one of these
    # candidate objects, which will be kept, and all other definitions are
    # deleted. Alternatively, the block may return nil, which will delete all
    # definitions. The block may be invoked many times from one call to 
    # {resolve_conflicts}, one for each unresolvable conflict.
    #
    # @param namespace [RbiGenerator::Namespace] The starting namespace to
    #   resolve conflicts in.
    # @yieldparam message [String] A descriptional message on what the conflict is.
    # @yieldparam candidates [Array<RbiGenerator::RbiObject>] The objects for
    #   which there is a conflict.
    # @yieldreturn [RbiGenerator::RbiObject] One of the +candidates+, which
    #   will be kept, or nil to keep none of them.
    # @return [void]
    def resolve_conflicts(namespace, &resolver)
      # Check for multiple definitions with the same name
      grouped_by_name_children = namespace.children.group_by(&:name)

      grouped_by_name_children.each do |name, children|
        if children.length > 1
          # Special case: do we have two methods, one of which is a class method 
          # and the other isn't? If so, do nothing - this is fine
          next if children.length == 2 &&
            children.all? { |c| c.is_a?(RbiGenerator::Method) } &&
            children.count { |c| T.cast(c, RbiGenerator::Method).class_method } == 1

          # Special case: do we have two attributes, one of which is a class 
          # attribute and the other isn't? If so, do nothing - this is fine
          next if children.length == 2 &&
            children.all? { |c| c.is_a?(RbiGenerator::Attribute) } &&
            children.count { |c| T.cast(c, RbiGenerator::Attribute).class_attribute } == 1

          # Special case: are they all clearly equal? If so, remove all but one
          if all_eql?(children)
            # All of the children are the same, so this deletes all of them
            namespace.children.delete(T.must(children.first))
          
            # Re-add one child
            namespace.children << T.must(children.first)
            next
          end

          # We found a conflict!
          # Start by removing all the conflicting items
          children.each do |c|
            namespace.children.delete(c)
          end

          # We can only try to resolve automatically if they're all the same 
          # type of object, so check that first
          children_type = single_type_of_array(children)
          unless children_type
            # The types aren't the same, so ask the resovler what to do, and
            # insert that (if not nil)
            choice = resolver.call("Different kinds of definition for the same name", children)
            namespace.children << choice if choice
            next
          end

          # Can the children merge themselves automatically? If so, let them
          first, *rest = children
          first, rest = T.must(first), T.must(rest)
          if T.must(first).mergeable?(T.must(rest))
            first.merge_into_self(rest)
            namespace.children << first
            next
          end

          # I give up! Let it be resolved manually somehow
          choice = resolver.call("Can't automatically resolve", children)
          namespace.children << choice if choice
        end
      end

      # Recurse to child namespaces
      namespace.children.each do |child|
        resolve_conflicts(child, &resolver) if RbiGenerator::Namespace === child
      end
    end

    private

    sig { params(arr: T::Array[T.untyped]).returns(T.nilable(Class)) }
    # Given an array, if all elements in the array are instances of the exact
    # same class, returns that class. If they are not, returns nil.
    #
    # @param arr [Array] The array.
    # @return [Class, nil] Either a class, or nil.
    def single_type_of_array(arr)
      array_types = arr.map { |c| c.class }.uniq
      array_types.length == 1 ? array_types.first : nil
    end

    sig { params(arr: T::Array[T.untyped]).returns(T::Boolean) }
    # Given an array, returns true if all elements in the array are equal by
    # +==+. (Assumes a transitive definition of +==+.)
    #
    # @param arr [Array] The array.
    # @return [Boolean] A boolean indicating if all elements are equal by +==+.
    def all_eql?(arr)
      arr.each_cons(2).all? { |x, y| x == y }
    end
  end
end
