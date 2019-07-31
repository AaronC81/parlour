# typed: ignore
RSpec.describe Parlour::Plugin do
  before :each do
    described_class.registered_plugins.clear
  end

  it 'registers new subclasses' do
    class A < Parlour::Plugin
    end

    expect(described_class.registered_plugins).to eq('A' => A)
  end

  it 'executes a list of plugins' do
    class Tracker
      @executed_plugins = []
      class << self
        attr_reader :executed_plugins
      end
    end

    class B < Parlour::Plugin
      def generate(*)
        Tracker.executed_plugins << self.class
      end
    end

    class C < Parlour::Plugin
      def generate(*)
        Tracker.executed_plugins << self.class
      end
    end

    class D < Parlour::Plugin
      def generate(*)
        Tracker.executed_plugins << self.class
      end
    end

    suppress_stdout do
      described_class.run_plugins(
        [B.new({}), C.new({}), D.new({})],
        Parlour::RbiGenerator.new,
        allow_failure: false
      )
    end
    expect(Tracker.executed_plugins).to eq [B, C, D]
  end
end
