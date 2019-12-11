# typed: true

require 'open3'
require 'json'

module Parlour
  module TypeLoader
    extend T::Sig

    # TODO: make this into a class which stores configuration and passes it to
    # all typeparsers

    sig { params(source: String, filename: T.nilable(String)).returns(RbiGenerator::Namespace) }
    # Converts Ruby source code into a tree of objects.
    #
    # @param [String] source The Ruby source code.
    # @param [String, nil] filename The filename to use when parsing this code.
    #   This may be used in error messages, but is optional.
    # @return [RbiGenerator::Namespace] The root of the object tree.
    def self.load_source(source, filename = nil)
      TypeParser.from_source(filename || '(source)', source).parse_all
    end

    sig { params(filename: String).returns(RbiGenerator::Namespace) }
    # Converts Ruby source code into a tree of objects from a file.
    #
    # @param [String] filename The name of the file to load code from.
    # @return [RbiGenerator::Namespace] The root of the object tree.
    def self.load_file(filename)
      load_source(File.read(filename), filename)
    end
  
    sig { params(root: String).returns(RbiGenerator::Namespace) }
    # Loads an entire Sorbet project using Sorbet's file table, obeying any
    # "typed: ignore" sigils, into a tree of objects.
    #
    # Files within sorbet/rbi/hidden-definitions are excluded, as they cause
    # merging issues with abstract classes due to sorbet/sorbet#1653.
    #
    # @param [String] root The root of the project; where the "sorbet" directory
    #   and "Gemfile" are located.
    # @return [RbiGenerator::Namespace] The root of the object tree.
    def self.load_project(root)
      stdin, stdout, stderr, wait_thr = T.unsafe(Open3).popen3(
        'bundle exec srb tc -p file-table-json',
        chdir: root
      )

      file_table_hash = JSON.parse(T.must(stdout.read))
      file_table_entries = file_table_hash['files']

      namespaces = T.let([], T::Array[Parlour::RbiGenerator::Namespace])
      file_table_entries.each do |file_table_entry|
        next if file_table_entry['sigil'] == 'Ignore' ||
          file_table_entry['strict'] == 'Ignore'

        rel_path = file_table_entry['path']
        next if rel_path.start_with?('./sorbet/rbi/hidden-definitions/')
        path = File.expand_path(rel_path, root)

        # There are some entries which are URLs to stdlib
        next unless File.exist?(path)

        namespaces << load_file(path)
      end

      raise 'project is empty' if namespaces.empty?

      first_namespace, *other_namespaces = namespaces
      first_namespace = T.must(first_namespace)
      other_namespaces = T.must(other_namespaces)

      raise 'cannot merge namespaces loaded from a project' \
        unless first_namespace.mergeable?(other_namespaces)
      first_namespace.merge_into_self(other_namespaces)

      ConflictResolver.new.resolve_conflicts(first_namespace) do |n, o|
        require 'pp'
        pp o.map(&:describe)
        pp T.unsafe(o).flat_map(&:children).map(&:describe)
        raise "conflict of #{o.length} objects: #{n}"
      end

      first_namespace
    end
  end
end
