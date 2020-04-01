# typed: ignore

require 'parser/current'

def n(type, *children)
  Parser::Builders::Default.new.send(:n, type, children, nil)
end

RSpec.describe Parlour::TypeParser do
  context Parlour::TypeParser::NodePath do
    let(:subject) { described_class.new([1, 2, 3, 4]) }
    let(:empty) { described_class.new([]) }

    it 'can be instantiated' do
      expect(subject.indices).to eq [1, 2, 3, 4]
      expect(empty.indices).to eq []
    end

    context '#parent' do
      it 'works for non-empty paths' do
        expect(subject.parent.indices).to eq [1, 2, 3]
      end

      it 'works for empty paths' do
        expect { empty.parent.indices }.to raise_error IndexError
      end
    end

    context '#child' do
      it 'works for non-empty paths' do
        expect(subject.child(5).indices).to eq [1, 2, 3, 4, 5]
      end

      it 'works for empty paths' do
        expect(empty.child(1).indices).to eq [1]
      end
    end

    context '#sibling' do
      it 'works for non-empty paths' do
        expect(subject.sibling(0).indices).to eq [1, 2, 3, 4]
        expect(subject.sibling(2).indices).to eq [1, 2, 3, 6]
        expect(subject.sibling(-3).indices).to eq [1, 2, 3, 1]

        expect { subject.sibling(-6).indices }.to raise_error ArgumentError
      end

      it 'works for empty paths' do
        expect { empty.sibling(2).indices }.to raise_error IndexError
      end
    end
  end

  context '#parse_sig_into_methods' do
    it 'works for a return-only sig' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { returns(Integer) }
        def foo
          3
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
      expect(meth).to have_attributes(name: 'foo', return_type: 'Integer',
        override: false, class_method: false)
    end

    it 'works for methods with simple parameters' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { params(x: String, y: T::Boolean).returns(Integer) }
        def foo(x, y = true)
          y ? x.length : 0
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
      expect(meth.return_type).to eq 'Integer'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
      expect(meth.final).to eq false

      expect(meth.parameters.length).to eq 2
      expect(meth.parameters[0]).to have_attributes(name: 'x', kind: :normal,
        type: 'String', default: nil)
      expect(meth.parameters[1]).to have_attributes(name: 'y', kind: :normal,
        type: 'T::Boolean', default: 'true')
    end

    it 'works for methods with complex parameters' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig do
          params(
            x: String, 
            y: T.nilable(T.any(Integer, T::Boolean)),
            z: Numeric,
            blk: T.proc.returns(T::Boolean)
          ).returns(T.nilable(Object))
        end
        def foo(x, y:, z: 3, &blk)
          nil
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
      expect(meth).to have_attributes(name: 'foo',
        return_type: 'T.nilable(Object)', override: false, final: false)

      expect(meth.parameters.length).to eq 4
      expect(meth.parameters[0]).to have_attributes(name: 'x', kind: :normal,
        type: 'String', default: nil)
      expect(meth.parameters[1]).to have_attributes(name: 'y:', kind: :keyword,
        type: 'T.nilable(T.any(Integer, T::Boolean))', default: nil)
      expect(meth.parameters[2]).to have_attributes(name: 'z:', kind: :keyword,
        type: 'Numeric', default: '3')
      expect(meth.parameters[3]).to have_attributes(name: '&blk', kind: :block,
        type: 'T.proc.returns(T::Boolean)', default: nil)
    end

    it 'works with splat-arguments' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig do
          params(
            args: Integer,
            kwargs: T::Hash[Object, Object]
          ).returns(T.nilable(Object))
        end
        def foo(*args, **kwargs)
          nil
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
      expect(meth).to have_attributes(name: 'foo',
        return_type: 'T.nilable(Object)', override: false)

      expect(meth.parameters[0]).to have_attributes(name: '*args', type: :splat,
        type: 'Integer')
      expect(meth.parameters[1]).to have_attributes(name: '**kwargs',
        type: :double_splat, type: 'T::Hash[Object, Object]')
    end

    it 'supports final methods' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig(:final) { returns(Integer) }
        def foo
          3
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
      expect(meth).to have_attributes(name: 'foo', return_type: 'Integer',
        override: false, final: true)
    end
    
    it 'supports class methods using self.x' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { params(x: String).returns(Integer) }
        def self.foo(x)
          3
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
      expect(meth).to have_attributes(name: 'foo', return_type: 'Integer',
        override: false, final: false, class_method: true)
      expect(meth.parameters.length).to eq 1
      expect(meth.parameters.first).to have_attributes(name: 'x',
        type: 'String')
    end

    it 'supports class methods within an eigenclass' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { params(x: String).returns(Integer) }
        def foo(x)
          3
        end
      RUBY

      meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0]), is_within_eigenclass: true).only
      expect(meth).to have_attributes(name: 'foo', return_type: 'Integer',
        override: false, final: false, class_method: true)
      expect(meth.parameters.length).to eq 1
      expect(meth.parameters.first).to have_attributes(name: 'x',
        type: 'String')
    end

    it 'errors on a self.x method within an eigenclass' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { params(x: String).returns(Integer) }
        def self.foo(x)
          3
        end
      RUBY

      expect do
        instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0]), is_within_eigenclass: true).only
      end.to raise_error Parlour::ParseError
    end

    context 'attributes' do
      it 'supports attr_accessor' do
        instance = described_class.from_source('(test)', <<-RUBY)
          sig { returns(String) }
          attr_accessor :foo
        RUBY

        meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
        expect(meth).to have_attributes(name: 'foo', return_type: 'String',
          kind: :accessor)
      end

      it 'supports attr_reader' do
        instance = described_class.from_source('(test)', <<-RUBY)
          sig { returns(String) }
          attr_reader :foo
        RUBY

        meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
        expect(meth).to have_attributes(name: 'foo', return_type: 'String',
          kind: :reader)
      end

      it 'supports attr_writer' do
        instance = described_class.from_source('(test)', <<-RUBY)
          sig { params(foo: String).returns(String) }
          attr_writer :foo
        RUBY

        meth = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0])).only
        expect(meth).to have_attributes(name: 'foo', return_type: 'String',
          kind: :writer)
        expect(meth.parameters.length).to eq 1
        expect(meth.parameters[0]).to have_attributes(name: 'foo',
          type: 'String')
      end

      it 'supports attribute with multiple names' do
        instance = described_class.from_source('(test)', <<-RUBY)
          sig { returns(String) }
          attr_accessor :foo, :bar, :baz
        RUBY

        meths = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0]))
        foo, bar, baz = meths

        expect(foo).to have_attributes(name: 'foo', return_type: 'String',
          kind: :accessor)
        expect(bar).to have_attributes(name: 'bar', return_type: 'String',
          kind: :accessor)
        expect(baz).to have_attributes(name: 'baz', return_type: 'String',
          kind: :accessor)
      end
    end
  end

  context '#parse_all' do
    it 'parses class structures' do
      instance = described_class.from_source('(test)', <<-RUBY)
        class A
          class B
            class C
              final!
              abstract!
            end

            class D
              abstract!
            end

            class E < B::D
            end
          end
        end
      RUBY

      root = instance.parse_all
      expect(root.children.length).to eq 1
      
      a = root.children.first
      expect(a).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(a).to have_attributes(name: 'A', superclass: nil, final: false, abstract: false)

      b = a.children.first
      expect(b).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(b).to have_attributes(name: 'B', superclass: nil, final: false, abstract: false)

      c, d, e = *b.children
      expect(c).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(d).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(e).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(c).to have_attributes(name: 'C', superclass: nil, final: true, abstract: true)
      expect(d).to have_attributes(name: 'D', superclass: nil, final: false, abstract: true)
      expect(e).to have_attributes(name: 'E', superclass: 'B::D', final: false, abstract: false)
    end

    it 'parses module structures containing methods' do
      instance = described_class.from_source('(test)', <<-RUBY)
        module A
          module B
            module C
              final!
              interface!
            end

            module D
              interface!

              sig { abstract.returns(String) }
              def foo; end

              sig { abstract.params(x: Integer).returns(Integer) }
              def bar(x); end
            end

            module E
              include D

              sig { override.returns(String) }
              def foo
                "hello"
              end

              sig { override.params(x: Integer).returns(Integer) }
              def bar(x)
                x + 1
              end
            end
          end
        end
      RUBY

      root = instance.parse_all
      expect(root.children.length).to eq 1
      
      a = root.children.first
      expect(a).to be_a Parlour::RbiGenerator::ModuleNamespace
      expect(a).to have_attributes(name: 'A', final: false, interface: false)

      b = a.children.first
      expect(b).to be_a Parlour::RbiGenerator::ModuleNamespace
      expect(b).to have_attributes(name: 'B', final: false, interface: false)

      c, d, e = *b.children
      expect(c).to be_a Parlour::RbiGenerator::ModuleNamespace
      expect(d).to be_a Parlour::RbiGenerator::ModuleNamespace
      expect(e).to be_a Parlour::RbiGenerator::ModuleNamespace
      expect(c).to have_attributes(name: 'C', final: true, interface: true)
      expect(d).to have_attributes(name: 'D', final: false, interface: true)
      expect(e).to have_attributes(name: 'E', final: false, interface: false)
      expect(e.includes.map(&:name)).to eq ['D']

      abs_foo, abs_bar = *d.children
      expect(abs_foo).to be_a Parlour::RbiGenerator::Method
      expect(abs_bar).to be_a Parlour::RbiGenerator::Method
      expect(abs_foo).to have_attributes(name: 'foo', abstract: true, return_type: 'String')
      expect(abs_bar).to have_attributes(name: 'bar', abstract: true, return_type: 'Integer')
      expect(abs_bar.parameters.length).to eq 1
      expect(abs_bar.parameters.first).to have_attributes(name: 'x', type: 'Integer')
      
      impl_foo, impl_bar = *e.children
      expect(impl_foo).to be_a Parlour::RbiGenerator::Method
      expect(impl_bar).to be_a Parlour::RbiGenerator::Method
      expect(impl_foo).to have_attributes(name: 'foo', abstract: false, override: true, return_type: 'String')
      expect(impl_bar).to have_attributes(name: 'bar', abstract: false, override: true, return_type: 'Integer')
      expect(impl_bar.parameters.length).to eq 1
      expect(impl_bar.parameters.first).to have_attributes(name: 'x', type: 'Integer')
    end

    it 'supports eigenclasses and class methods' do
      instance = described_class.from_source('(test)', <<-RUBY)
        class A
          class << self
            sig { returns(Integer) }
            def foo
              3
            end
          end

          sig { returns(String) }
          def self.bar
            "hello"
          end

          sig { returns(T::Boolean) }
          def baz
            true
          end
        end
      RUBY

      root = instance.parse_all
      expect(root.children.length).to eq 1
      
      a = root.children.first
      expect(a).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(a).to have_attributes(name: 'A', final: false)

      foo, bar, baz = *a.children
      expect(foo).to be_a Parlour::RbiGenerator::Method
      expect(bar).to be_a Parlour::RbiGenerator::Method
      expect(baz).to be_a Parlour::RbiGenerator::Method
      expect(foo).to have_attributes(name: 'foo', return_type: 'Integer',
        class_method: true)
      expect(bar).to have_attributes(name: 'bar', return_type: 'String',
        class_method: true)
      expect(baz).to have_attributes(name: 'baz', return_type: 'T::Boolean',
        class_method: false)
    end

    it 'supports expansion of names like A::B::C' do
      instance = described_class.from_source('(test)', <<-RUBY)
        module A::B::C
          class D::E::F < G; end
        end
      RUBY

      root = instance.parse_all
      expect(root.children.length).to eq 1

      a = root.children.first
      expect(a).to be_a Parlour::RbiGenerator::Namespace
      expect(a).to have_attributes(name: 'A', final: false)

      b = a.children.first
      expect(b).to be_a Parlour::RbiGenerator::Namespace
      expect(b).to have_attributes(name: 'B', final: false)

      c = b.children.first
      expect(c).to be_a Parlour::RbiGenerator::ModuleNamespace
      expect(c).to have_attributes(name: 'C', final: false)

      d = c.children.first
      expect(d).to be_a Parlour::RbiGenerator::Namespace
      expect(d).to have_attributes(name: 'D', final: false)
      
      e = d.children.first
      expect(e).to be_a Parlour::RbiGenerator::Namespace
      expect(e).to have_attributes(name: 'E', final: false)

      f = e.children.first
      expect(f).to be_a Parlour::RbiGenerator::ClassNamespace
      expect(f).to have_attributes(name: 'F', final: false, superclass: 'G')
    end
  end

  it 'parses type parameters' do
    instance = described_class.from_source('(test)', <<-RUBY)
      sig { type_parameters(:A, :B).params(x: T.type_parameter(:A), y: T.type_parameter(:B)).returns(T.type_parameter(:A)) }
      def id(x, y)
        x
      end
    RUBY

    id = instance.parse_sig_into_methods(Parlour::TypeParser::NodePath.new([0]))[0]

    expect(id).to have_attributes(name: 'id',
      return_type: 'T.type_parameter(:A)',
      type_parameters: [:A, :B])
  end

  it 'handles empty and comment-only files' do
    instance = described_class.from_source('(test)', '')

    root = instance.parse_all
    expect(root.children).to be_empty

    instance = described_class.from_source('(test)', <<-RUBY)
      # Something

      # Something else
    RUBY

    root = instance.parse_all
    expect(root.children).to be_empty
  end

  it 'parses enums' do
    instance = described_class.from_source('(test)', <<-RUBY)
      class Directions < T::Enum
        enums do
          North = new
          South = new
          West = new
          East = new("Some custom serialization")
        end

        sig { returns(String) }
        def self.mnemonic; end
      end
    RUBY

    root = instance.parse_all
    directions = root.children.first

    expect(directions).to be_a Parlour::RbiGenerator::EnumClassNamespace
    expect(directions.enums.length).to eq 4
    expect(directions.enums.first).to eq 'North'
    expect(directions.enums.last).to eq ['East', '"Some custom serialization"']
    
    expect(directions.children.find { |x| x.name == 'mnemonic' }).to be_a Parlour::RbiGenerator::Method
  end
end
