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
      expect(subject.indeces).to eq [1, 2, 3, 4]
      expect(empty.indeces).to eq []
    end

    context '#parent' do
      it 'works for non-empty paths' do
        expect(subject.parent.indeces).to eq [1, 2, 3]
      end

      it 'works for empty paths' do
        expect { empty.parent.indeces }.to raise_error IndexError
      end
    end

    context '#child' do
      it 'works for non-empty paths' do
        expect(subject.child(5).indeces).to eq [1, 2, 3, 4, 5]
      end

      it 'works for empty paths' do
        expect(empty.child(1).indeces).to eq [1]
      end
    end

    context '#sibling' do
      it 'works for non-empty paths' do
        expect(subject.sibling(0).indeces).to eq [1, 2, 3, 4]
        expect(subject.sibling(2).indeces).to eq [1, 2, 3, 6]
        expect(subject.sibling(-3).indeces).to eq [1, 2, 3, 1]

        expect { subject.sibling(-6).indeces }.to raise_error ArgumentError
      end

      it 'works for empty paths' do
        expect { empty.sibling(2).indeces }.to raise_error IndexError
      end
    end
  end

  context '#parse_sig' do
    it 'works for a return-only sig' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { returns(Integer) }
        def foo
          3
        end
      RUBY

      meth = instance.parse_sig(Parlour::TypeParser::NodePath.new([0]))
      expect(meth.return_type).to eq 'Integer'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
    end

    it 'works for methods with simple parameters' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig { params(x: String, y: T::Boolean).returns(Integer) }
        def foo(x, y = true)
          y ? x.length : 0
        end
      RUBY

      meth = instance.parse_sig(Parlour::TypeParser::NodePath.new([0]))
      expect(meth.return_type).to eq 'Integer'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
      expect(meth.final).to eq false

      expect(meth.parameters.length).to eq 2
      expect(meth.parameters[0].name).to eq 'x'
      expect(meth.parameters[0].kind).to eq :normal
      expect(meth.parameters[0].type).to eq 'String'
      expect(meth.parameters[0].default).to eq nil
      expect(meth.parameters[1].name).to eq 'y'
      expect(meth.parameters[1].kind).to eq :normal
      expect(meth.parameters[1].type).to eq 'T::Boolean'
      expect(meth.parameters[1].default).to eq 'true'
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

      meth = instance.parse_sig(Parlour::TypeParser::NodePath.new([0]))
      expect(meth.return_type).to eq 'T.nilable(Object)'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
      expect(meth.final).to eq false

      expect(meth.parameters.length).to eq 4
      expect(meth.parameters[0].name).to eq 'x'
      expect(meth.parameters[0].kind).to eq :normal
      expect(meth.parameters[0].type).to eq 'String'
      expect(meth.parameters[0].default).to eq nil
      expect(meth.parameters[1].name).to eq 'y:'
      expect(meth.parameters[1].kind).to eq :keyword
      expect(meth.parameters[1].type).to eq 'T.nilable(T.any(Integer, T::Boolean))'
      expect(meth.parameters[1].default).to eq nil
      expect(meth.parameters[2].name).to eq 'z:'
      expect(meth.parameters[2].kind).to eq :keyword
      expect(meth.parameters[2].type).to eq 'Numeric'
      expect(meth.parameters[2].default).to eq '3'
      expect(meth.parameters[3].name).to eq '&blk'
      expect(meth.parameters[3].kind).to eq :block
      expect(meth.parameters[3].type).to eq 'T.proc.returns(T::Boolean)'
      expect(meth.parameters[3].default).to eq nil
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

      meth = instance.parse_sig(Parlour::TypeParser::NodePath.new([0]))
      expect(meth.return_type).to eq 'T.nilable(Object)'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false

      expect(meth.parameters.length).to eq 2
      expect(meth.parameters[0].name).to eq '*args'
      expect(meth.parameters[0].kind).to eq :splat
      expect(meth.parameters[0].type).to eq 'Integer'
      expect(meth.parameters[1].name).to eq '**kwargs'
      expect(meth.parameters[1].kind).to eq :double_splat
      expect(meth.parameters[1].type).to eq 'T::Hash[Object, Object]'
    end

    it 'supports final methods' do
      instance = described_class.from_source('(test)', <<-RUBY)
        sig(:final) { returns(Integer) }
        def foo
          3
        end
      RUBY

      meth = instance.parse_sig(Parlour::TypeParser::NodePath.new([0]))
      expect(meth.return_type).to eq 'Integer'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
      expect(meth.final).to eq true
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

    it 'parses mixed namespace structures' do

    end
  end
end
