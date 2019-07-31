# typed: ignore
require 'aruba/rspec'
RSpec.describe 'the Parlour CLI', type: :aruba do
  let(:plugin_a_foo_file) do
    <<-RUBY
      class PluginAFoo < Parlour::Plugin
        def generate(root)
          root.create_class('A') do |a|
            a.create_method('foo')
          end
        end
      end
    RUBY
  end

  let(:plugin_b_file) do
    <<-RUBY
      class PluginB < Parlour::Plugin
        def generate(root)
          root.create_class('B')
        end
      end
    RUBY
  end

  let(:plugin_a_bar_file) do
    <<-RUBY
      class PluginABar < Parlour::Plugin
        def generate(root)
          root.create_class('A') do |a|
            a.create_method('bar')
          end
        end
      end
    RUBY
  end

  let(:plugin_a_interface_file) do
    <<-RUBY
      class PluginAInterface < Parlour::Plugin
        def generate(root)
          root.create_class('A', interface: true)
        end
      end
    RUBY
  end

  before :each do 
    %w[plugin_a_foo plugin_b plugin_a_bar plugin_a_interface].each do |file|
      write_file "#{file}.rb", send("#{file}_file")
    end
  end

  def parlour_cli
    filepath = File.join(File.dirname(__FILE__), '..', 'exe', 'parlour')
    run_command("\"#{filepath}\"")
  end

  it 'fails gracefully without a .parlour' do
    parlour_cli
    expect(last_command_started).not_to be_successfully_executed
    expect(last_command_started).to have_output /no \.parlour/
  end

  context 'with a .parlour' do
    it 'works with a single plugin' do
      write_file '.parlour', <<-YAML
        output_file: out.rbi
        relative_requires:
          - plugin_a_foo.rb
        plugins:
          PluginAFoo: {}
      YAML
      parlour_cli
      expect(last_command_started).to be_successfully_executed
      expect(read('out.rbi').join("\n")).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        class A
          sig { void }
          def foo; end
        end
      RUBY
    end

    it 'works with multiple non-conflicting plugins' do
      write_file '.parlour', <<-YAML
        output_file: out.rbi
        relative_requires:
          - plugin_a_foo.rb
          - plugin_b.rb
        plugins:
          PluginAFoo: {}
          PluginB: {}
      YAML
      parlour_cli
      expect(last_command_started).to be_successfully_executed
      expect(read('out.rbi').join("\n")).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        class A
          sig { void }
          def foo; end
        end

        class B
        end
      RUBY
    end

    it 'works with multiple plugins which must be merged' do
      write_file '.parlour', <<-YAML
        output_file: out.rbi
        relative_requires:
          - plugin_a_foo.rb
          - plugin_a_bar.rb
        plugins:
          PluginAFoo: {}
          PluginABar: {}
      YAML
      parlour_cli
      expect(last_command_started).to be_successfully_executed
      expect(read('out.rbi').join("\n")).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        class A
          sig { void }
          def foo; end

          sig { void }
          def bar; end
        end
      RUBY
    end
  end
end