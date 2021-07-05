require 'fileutils'
require 'open3'
require 'yaml'

TMP_ROOT = '/tmp/parlour-test'
FileUtils.rm_rf(TMP_ROOT)
FileUtils.mkdir_p(TMP_ROOT)

RSpec.describe 'command-line interface' do
  # Dyamically run a test for each subdirectory of /spec/cli
  Dir[File.join(__dir__, "cli", "*")].each do |test_dir|
    test_dir_basename = File.basename(test_dir)
    test_name = test_dir_basename.gsub('_', ' ')

    it test_name do
      # Copy the test into /tmp
      tmp_dir = File.join(TMP_ROOT, test_dir_basename)
      FileUtils.cp_r(test_dir, tmp_dir)

      # Create a basic Sorbet directory
      FileUtils.mkdir(File.join(tmp_dir, "sorbet"))
      File.write(File.join(tmp_dir, "sorbet", "config"), "--dir\n.")

      Bundler.with_unbundled_env do
        Dir.chdir(tmp_dir) do
          # Run the shell script (ensuring we use these gems)
          Open3.popen2e(
            { "BUNDLE_GEMFILE" => File.expand_path(File.join(__dir__, "..", "Gemfile")) },
            "sh", File.join(tmp_dir, "shell")
          ) do |input, output, wait|
            # Load the expected result
            expected = YAML.load_file(File.join(tmp_dir, "expect.yaml"))

            # Check result
            expect(expected['success']).to eq wait.value.success?
            expected['files']&.each do |name, contents|
              expect(File.read(File.join(tmp_dir, name))).to eq contents
            end

            # TODO: check cli output
          end
        end
      end
    end
  end
end
