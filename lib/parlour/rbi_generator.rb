# typed: true
module Parlour
  # The RBI generator.
  class RbiGenerator < Generator
    def initialize(**hash)
      super
      @root = RbiGenerator::Namespace.new(self)
    end

    sig { overridable.returns(RbiGenerator::Namespace) }
    # The root {Namespace} of this generator.
    # @return [Namespace]
    attr_reader :root

    sig { overridable.params(strictness: String).returns(String) }
    # Returns the complete contents of the generated RBI file as a string.
    #
    # @return [String] The generated RBI file
    def rbi(strictness = 'strong')
      # TODO: Early test option - convert to RBS if requested
      # Absolutely remove this later on
      if ENV['PARLOUR_CONVERT_TO_RBS']
        # Perform conversion
        root.generalize_from_rbi!
        rbs_gen = Parlour::RbsGenerator.new
        converter = Parlour::Conversion::RbiToRbs.new(rbs_gen)
        root.children.each do |child|
          converter.convert_object(child, rbs_gen.root)
        end

        # Write the final RBS
        rbs_gen.rbs
      else
        "# typed: #{strictness}\n" + root.generate_rbi(0, options).join("\n") + "\n"
      end
    end
  end
end
