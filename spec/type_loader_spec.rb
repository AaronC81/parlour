RSpec.describe Parlour::TypeLoader do
  it 'can load source' do
    ns = described_class.load_source(<<-RUBY)
      module A
        class B
          sig { returns(Integer) }
          def foo; 3; end

          sig { returns(T::Boolean) }
          def bar; true; end
        end

        class C
          sig { returns(String) }
          def baz; "hello"; end
        end
      end

      module D
        class E
          sig { returns(Float) }
          def asdf; 3.14; end
        end
      end
    RUBY

    expect(ns.children.map(&:name)).to match_array(['A', 'D'])

    a = ns.children.find { |child| child.name == 'A' }
    expect(a).to be_a Parlour::RbiGenerator::ModuleNamespace
    expect(a.children.map(&:name)).to match_array(['B', 'C'])

    b = a.children.find { |child| child.name == 'B' }
    expect(b).to be_a Parlour::RbiGenerator::ClassNamespace
    expect(b.children.map(&:name)).to match_array(['foo', 'bar'])

    foo = b.children.find { |child| child.name == 'foo' }
    expect(foo).to be_a Parlour::RbiGenerator::Method
    expect(foo.return_type).to eq 'Integer'

    bar = b.children.find { |child| child.name == 'bar' }
    expect(bar).to be_a Parlour::RbiGenerator::Method
    expect(bar.return_type).to eq 'T::Boolean'

    c = a.children.find { |child| child.name == 'C' }
    expect(c).to be_a Parlour::RbiGenerator::ClassNamespace
    expect(c.children.map(&:name)).to match_array(['baz'])

    baz = c.children.find { |child| child.name == 'baz' }
    expect(baz).to be_a Parlour::RbiGenerator::Method
    expect(baz.return_type).to eq 'String'

    d = ns.children.find { |child| child.name == 'D' }
    expect(d).to be_a Parlour::RbiGenerator::ModuleNamespace
    expect(d.children.map(&:name)).to match_array(['E'])

    e = d.children.find { |child| child.name == 'E' }
    expect(e).to be_a Parlour::RbiGenerator::ClassNamespace
    expect(e.children.map(&:name)).to match_array(['asdf'])

    asdf = e.children.find { |child| child.name == 'asdf' }
    expect(asdf).to be_a Parlour::RbiGenerator::Method
    expect(asdf.return_type).to eq 'Float'
  end

  context 'can load this project' do
    it 'fully' do
      # Is this like a quine, in test form? :)
      project_root = described_class.load_project('.')
      parlour_module = project_root.children.find { |x| x.name == 'Parlour' }
      expect(parlour_module).to be_a Parlour::RbiGenerator::ModuleNamespace

      rbi_generator = parlour_module.children.find { |x| x.name == 'RbiGenerator' }
      expect(rbi_generator).to be_a Parlour::RbiGenerator::ClassNamespace

      rbi_generator_init = rbi_generator.children.find { |x| x.name == 'initialize' }
      expect(rbi_generator_init).to have_attributes(class_method: false,
        return_type: nil)
    end

    it 'with exclusions' do
      project_root = described_class.load_project('.',
        exclusions: ['lib/parlour/rbi_generator/arbitrary.rb'])
      parlour_module = project_root.children.find { |x| x.name == 'Parlour' }
      expect(parlour_module).to be_a Parlour::RbiGenerator::ModuleNamespace

      rbi_generator = parlour_module.children.find { |x| x.name == 'RbiGenerator' }
      expect(rbi_generator).to be_a Parlour::RbiGenerator::ClassNamespace

      rbi_generator_init = rbi_generator.children.find { |x| x.name == 'initialize' }
      expect(rbi_generator_init).to have_attributes(class_method: false,
        return_type: nil)

      # This file was not excluded
      expect(rbi_generator.children.find { |x| x.name == 'Attribute' }).not_to be nil
      # This file was excluded
      expect(rbi_generator.children.find { |x| x.name == 'Arbitrary' }).to be nil
    end
  end

  context 'with undeclared block arg' do
    let(:source) {
      (<<-RUBY)
        class A
          sig { params(a: String).void }
          def bar(a, &blk); end
        end
      RUBY
    }

    it 'can parse the source' do
      # We just care that this doesn't error
      namespace = described_class.load_source(source)
      expect(namespace.children.map(&:name)).to match_array(['A'])
    end
  end
end
