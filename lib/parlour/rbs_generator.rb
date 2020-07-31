# typed: true
module Parlour
    # The RBS generator.
    class RbsGenerator < Generator  
      sig { overridable.params(strictness: String).returns(String) }
      # Returns the complete contents of the generated RBS file as a string.
      #
      # @return [String] The generated RBS file
      def rbs(strictness = 'strong')
        root.generate_rbi(0, options).join("\n")
      end
    end
  end
  