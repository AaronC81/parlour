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
      TypeParser.from_source(filename || '(source)', source).parse_all
    end

    def self.load_file; end
    
    def self.load_project; end
  end
end
