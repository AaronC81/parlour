# typed: true
module Parlour
  # The RBI generator.
  class RbiGenerator < Generator
    sig { overridable.params(strictness: String).returns(String) }
    # Returns the complete contents of the generated RBI file as a string.
    #
    # @return [String] The generated RBI file
    def rbi(strictness = 'strong')
      "# typed: #{strictness}\n" + root.generate_rbi(0, options).join("\n") + "\n"
    end
  end
end
