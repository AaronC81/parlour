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
      Debugging.debug_puts(self, Debugging::Tree.begin("Resolving conflicts for #{namespace.name}..."))

      # Check for multiple definitions with the same name
      # (Special case here: writer attributes get an "=" appended to their name)
      grouped_by_name_children = namespace.children.group_by do |child|
        if RbiGenerator::Attribute === child && child.kind == :writer
          "#{child.name}=" unless child.name.end_with?('=')
        else
          child.name
        end
      end
      
      grouped_by_name_children.each do |name, children|
        Debugging.debug_puts(self, Debugging::Tree.begin("Checking children named #{name}..."))

        if children.length > 1
          Debugging.debug_puts(self, Debugging::Tree.here("Possible conflict between #{children.length} objects"))

          # Special case: do we have two methods, one of which is a class method 
          # and the other isn't? If so, do nothing - this is fine
          if children.length == 2 &&
            children.all? { |c| c.is_a?(RbiGenerator::Method) } &&
            children.count { |c| T.cast(c, RbiGenerator::Method).class_method } == 1

            Debugging.debug_puts(self, Debugging::Tree.end("One is an instance method and one is a class method; no resolution required"))
            next
          end

          # Special case: if we remove the namespaces, is everything either an
          # include or an extend? If so, do nothing - this is fine
          if children \
            .reject { |c| c.is_a?(RbiGenerator::Namespace) }
            .then do |x|
              !x.empty? && x.all? do |c|
                c.is_a?(RbiGenerator::Include) || c.is_a?(RbiGenerator::Extend)
              end
            end
            
            Debugging.debug_puts(self, Debugging::Tree.end("Includes/extends do not conflict with namespaces; no resolution required"))
            next
          end

          # Special case: do we have two attributes, one of which is a class 
          # attribute and the other isn't? If so, do nothing - this is fine
          if children.length == 2 &&
            children.all? { |c| c.is_a?(RbiGenerator::Attribute) } &&
            children.count { |c| T.cast(c, RbiGenerator::Attribute).class_attribute } == 1

            Debugging.debug_puts(self, Debugging::Tree.end("One is an instance attribute and one is a class attribute; no resolution required"))
            next
          end

          # Special case: are they all clearly equal? If so, remove all but one
          if all_eql?(children)
            Debugging.debug_puts(self, Debugging::Tree.end("All children are identical"))

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

          # Check that the types of the given objects allow them to be merged,
          # and get the strategy to use
          strategy = merge_strategy(children)
          unless strategy
            Debugging.debug_puts(self, Debugging::Tree.end("Children are unmergeable types; requesting manual resolution"))
            # The types aren't the same, so ask the resolver what to do, and
            # insert that (if not nil)
            choice = resolver.call("Different kinds of definition for the same name", children)
            namespace.children << choice if choice
            next
          end

          case strategy
          when :normal
            first, *rest = children
          when :differing_namespaces
            # Let the namespaces be merged normally, but handle the method here
            namespaces, non_namespaces = children.partition { |x| RbiGenerator::Namespace === x }

            # If there is any non-namespace item in this conflict, it should be
            # a single method
            if non_namespaces.length != 0
              unless non_namespaces.length == 1 && RbiGenerator::Method === non_namespaces.first
                Debugging.debug_puts(self, Debugging::Tree.end("Non-namespace item in a differing namespace conflict is not a single method; requesting manual resolution"))
                # The types aren't the same, so ask the resolver what to do, and
                # insert that (if not nil)
                choice = resolver.call("Non-namespace item in a differing namespace conflict is not a single method", non_namespaces)
                non_namespaces = []
                non_namespaces << choice if choice
              end 
            end

            non_namespaces.each do |x|
              namespace.children << x
            end

            first, *rest = namespaces
          else
            raise 'unknown merge strategy; this is a Parlour bug'
          end

          # Can the children merge themselves automatically? If so, let them
          first, rest = T.must(first), T.must(rest)
          if T.must(first).mergeable?(T.must(rest))
            Debugging.debug_puts(self, Debugging::Tree.end("Children are all mergeable; resolving automatically"))
            first.merge_into_self(rest)
            namespace.children << first
            next
          end

          # I give up! Let it be resolved manually somehow
          Debugging.debug_puts(self, Debugging::Tree.end("Unable to resolve automatically; requesting manual resolution"))
          choice = resolver.call("Can't automatically resolve", children)
          namespace.children << choice if choice
        else
          Debugging.debug_puts(self, Debugging::Tree.end("No conflicts"))
        end
      end

      Debugging.debug_puts(self, Debugging::Tree.here("Resolving children..."))

      # Recurse to child namespaces
      namespace.children.each do |child|
        resolve_conflicts(child, &resolver) if RbiGenerator::Namespace === child
      end

      Debugging.debug_puts(self, Debugging::Tree.end("All children done"))
    end

    private

    sig { params(arr: T::Array[T.untyped]).returns(T.nilable(Symbol)) }
    # Given an array, if all elements in the array are instances of the exact
    # same class or are otherwise mergeable (for example Namespace and 
    # ClassNamespace), returns the kind of merge which needs to be made. A
    # return value of nil indicates that the values cannot be merged.
    #
    # The following kinds are available:
    #   - They are all the same. (:normal)
    #   - There are exactly two types, one of which is Namespace and other is a 
    #     subclass of it. (:differing_namespaces)
    #   - One of them is Namespace or a subclass (or both, as described above),
    #     and the only other is Method. (also :differing_namespaces) 
    #
    # @param arr [Array] The array.
    # @return [Symbol] The merge strategy to use, or nil if they can't be
    #   merged.
    def merge_strategy(arr)
      # If they're all the same type, they can be merged easily
      array_types = arr.map { |c| c.class }.uniq
      return :normal if array_types.length == 1

      # Find all the namespaces and non-namespaces
      namespace_types, non_namespace_types = array_types.partition { |x| x <= RbiGenerator::Namespace }

      # If there are two namespace types, one should be Namespace and the other
      # should be a subclass of it
      if namespace_types.length == 2
        exactly_namespace, exactly_one_subclass = namespace_types.partition { |x| x == RbiGenerator::Namespace }

        return nil unless exactly_namespace.length == 1 \
          && exactly_one_subclass.length == 1 \
          && exactly_one_subclass.first < RbiGenerator::Namespace
      elsif namespace_types.length != 1
        # The only other valid number of namespaces is 1, where we don't need to
        # check anything
        return nil
      end
      
      # It's OK, albeit cursed, for there to be a method with the same name as
      # a namespace (Rainbow does this)
      return nil if non_namespace_types.length != 0 && non_namespace_types != [RbiGenerator::Method]

      :differing_namespaces
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
