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
end