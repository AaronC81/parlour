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
    @@executed_plugins = []

    class B < Parlour::Plugin
      def generate(*)
        @@executed_plugins << self.class
      end
    end

    class C < Parlour::Plugin
      def generate(*)
        @@executed_plugins << self.class
      end
    end

    class D < Parlour::Plugin
      def generate(*)
        @@executed_plugins << self.class
      end
    end

    described_class.run_plugins(
      [B.new({}), C.new({}), D.new({})],
      Parlour::RbiGenerator.new,
      allow_failure: false
    )
    expect(@@executed_plugins).to eq [B, C, D]
  end
end
