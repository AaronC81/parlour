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
      grouped_by_name_children = namespace.children.group_by do |rbi_obj|
        if RbiGenerator::ModuleNamespace === rbi_obj \
          || RbiGenerator::ClassNamespace === rbi_obj \
          || RbiGenerator::Method === rbi_obj
          rbi_obj.name
        else
          raise "unsupported child of type #{T.cast(rbi_obj, Object).class}"
        end
      end

      grouped_by_name_children.each do |name, children|
        if children.length > 1
          # We found a conflict!
          # Start by removing all the conflicting items
          children.each do |c|
            namespace.children.delete(c)
          end

          # We can only try to resolve automatically if they're all the same 
          # type of object, so check that first
          children_types = children.map { |c| T.cast(c, Object).class }.uniq
          if children_types.size != 1
            # The types aren't the same, so ask the resovler what to do, and
            # insert that (if not nil)
            choice = resolver.call("Different kinds of definition for the same name", children)
            namespace.children << choice if choice
            next
          end
          children_type = T.must(children_types.first)

          # Are all of the children equivalent? If so, just keep one of them
          if children.each_cons(2).all? { |x, y| x == y }
            namespace.children << T.must(children.first)
            next
          end

          # TODO: merge classes if their subclass and abstractness are compatible
          # TODO: merge modules if their interfaceness is compatible

          # I give up! Let it be resolved manually somehow
          choice = resolver.call("Can't automatically resolve", children)
          namespace.children << choice if choice
        end
      end

      # TODO: recurse to deeper namespaces
    end
  end
end