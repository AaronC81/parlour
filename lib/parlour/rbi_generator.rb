# typed: true
module Parlour
  # The RBI generator.
  class RbiGenerator < Generator
    sig { overridable.returns(T.nilable(Plugin)) }
    # The plugin which is currently generating new definitions.
    # {Plugin#run_plugins} controls this value.
    # @return [Plugin, nil]
    attr_accessor :current_plugin

    sig { overridable.params(strictness: String).returns(String) }
    # Returns the complete contents of the generated RBI file as a string.
    #
    # @return [String] The generated RBI file
    def rbi(strictness = 'strong')
      "# typed: #{strictness}\n" + root.generate_rbi(0, options).join("\n") + "\n"
    end
  end
end
