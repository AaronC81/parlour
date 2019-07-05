# typed: true
module Parlour
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
    def resolve_conflicts(namespace, &resolver)
      # Check for multiple definitions with the same name
      grouped_by_name_children = namespace.children.group_by(&:name)

      grouped_by_name_children.each do |name, children|
        if children.length > 1
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

    sig { params(arr: T::Array[T.untyped]).returns(T.nilable(Class)) }
    def single_type_of_array(arr)
      array_types = arr.map { |c| c.class }.uniq
      array_types.length == 1 ? array_types.first : nil
    end

    sig { params(arr: T::Array[T.untyped]).returns(T::Boolean) }
    def all_eql?(arr)
      arr.each_cons(2).all? { |x, y| x == y }
    end
  end
end