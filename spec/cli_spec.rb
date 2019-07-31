require 'aruba/rspec'

RSpec.describe 'the Parlour CLI', type: :aruba do
  let(:plugin_a_foo_file) do
    <<-RUBY
      class Plugin1 < Parlour::Plugin
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
      class Plugin2 < Parlour::Plugin
        def generate(root)
          root.create_class('B')
        end
      end
    RUBY
  end

  let(:plugin_a_bar_file) do
    <<-RUBY
      class Plugin3 < Parlour::Plugin
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
      class Plugin3 < Parlour::Plugin
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
    run_command("bundle exec \"#{filepath}\"")
  end

  it 'fails without a .parlour' do
    parlour_cli
    expect(last_command_started.exit_status).not_to be 0
    expect(last_command_started).to have_output /\.parlour is missing/
  end
end