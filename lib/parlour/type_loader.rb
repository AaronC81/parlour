# typed: true

module Parlour
  module TypeLoader
    extend T::Sig

    sig { params(source: String, filename: T.nilable(String)).returns(RbiGenerator::Namespace) }
    # Converts Ruby source code into a tree of objects.
    #
    # @param [String] source The Ruby source code.
    # @param [String, nil] filename The filename to use when parsing this code.
    #   This may be used in error messages, but is optional.
    # @return [RbiGenerator::Namespace] The root of the object tree.
    def self.load_source(source, filename = nil)
      parser = TypeParser.from_source(filename || '(source)', source)
      
      # Find all full definitions
      all_sigs = parser.find_sigs
      root_namespaces = all_sigs.map do |this_sig|
        parser.full_definition_for_sig(this_sig)
      end

      # Create a new root namespace which contains all of them
      final_root_namespace = RbiGenerator::Namespace.new(DetachedRbiGenerator.new)
      root_namespaces.each do |ns|
        final_root_namespace.children.concat(ns.children)
      end

      # Resolve conflicts
      ConflictResolver.new.resolve_conflicts(final_root_namespace) do |*args|
        raise "the conflict resolver encountered errors when trying to merge " \
          "parsed types, which should never happen (does srb tc pass?): #{args}"
      end

      final_root_namespace
    end

    def self.load_file; end
    
    def self.load_project; end
  end
end
