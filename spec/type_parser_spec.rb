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
end
