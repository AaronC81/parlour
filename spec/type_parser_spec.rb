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

  context '#find_sigs' do
    it 'works in basic cases' do
      instance = described_class.new(
        n(:module,
          n(:const, nil, :A),
          n(:begin,
            n(:block,
              n(:send, nil, :sig),
              n(:args),
              n(:send, nil, :returns, n(:const, nil, :Integer))),
            n(:def, :x, n(:args), n(:int, 3))))
      )

      sigs = instance.find_sigs
      expect(sigs.length).to eq 1
      expect(sigs[0]).to be_a Parlour::TypeParser::NodePath
      expect(sigs[0].indeces).to eq [1, 0]
    end

    it 'finds every sig, including ones in invalid locations, to be pruned later' do
      instance = described_class.new(
        n(:module,
          n(:const, nil, :B),
          n(:begin,
            n(:block,
              n(:send, nil, :sig),
              n(:args),
              n(:send, nil, :returns, n(:const, nil, :String))),
            n(:def,
              :x,
              n(:args),
              n(:block,
                n(:send, nil, :sig),
                n(:args),
                n(:send, nil, :returns, n(:const, nil, :Integer))))))
      )

      sigs = instance.find_sigs
      expect(sigs.length).to eq 2
      expect(sigs[0].indeces).to eq [1, 0]
      expect(sigs[1].indeces).to eq [1, 1, 2]
    end
  end

  context '#parse_sig' do
    it 'works for a return-only sig' do
      instance = described_class.from_source('(test)', <<-RUBY)
        module A
          sig { returns(Integer) }
          def foo
            3
          end
        end
      RUBY

      sigs = instance.find_sigs
      expect(sigs.length).to be 1

      meth = instance.parse_sig(sigs[0])
      expect(meth.return_type).to eq 'Integer'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
    end

    it 'works for methods with simple parameters' do
      instance = described_class.from_source('(test)', <<-RUBY)
        module A
          sig { params(x: String, y: T::Boolean).returns(Integer) }
          def foo(x, y = true)
            y ? x.length : 0
          end
        end
      RUBY

      sigs = instance.find_sigs
      expect(sigs.length).to be 1

      meth = instance.parse_sig(sigs[0])
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
        module A
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
        end
      RUBY

      sigs = instance.find_sigs
      expect(sigs.length).to be 1

      meth = instance.parse_sig(sigs[0])
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
        module A
        sig do
          params(
            args: Integer,
            kwargs: T::Hash[Object, Object]
          ).returns(T.nilable(Object))
        end
        def foo(*args, **kwargs)
          nil
        end
      end
      RUBY

      sigs = instance.find_sigs
      expect(sigs.length).to be 1

      meth = instance.parse_sig(sigs[0])
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
        module A
          sig(:final) { returns(Integer) }
          def foo
            3
          end
        end
      RUBY

      sigs = instance.find_sigs
      expect(sigs.length).to be 1

      meth = instance.parse_sig(sigs[0])
      expect(meth.return_type).to eq 'Integer'
      expect(meth.name).to eq 'foo'
      expect(meth.override).to eq false
      expect(meth.final).to eq true
    end 
  end
end
