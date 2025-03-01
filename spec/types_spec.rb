# typed: ignore

require 'parser/current'

# TODO: Add unit tests for more types
RSpec.describe Parlour::Types do
  describe 'Generic' do
    subject(:type) {
      Parlour::Types::Generic.new(
        Parlour::Types::Raw.new('Mapper'),
        [
          Parlour::Types::Raw.new('String'),
          Parlour::Types::Generic.new(
            Parlour::Types::Raw.new('Mapper'),
            [
              Parlour::Types::Raw.new('String'),
              Parlour::Types::Raw.new('Integer'),
            ]
          )
        ]
      )
    }

    it { expect(type.type).to eq(Parlour::Types::Raw.new('Mapper')) }
    it do
      expect(type.type_params).to eq([
        Parlour::Types::Raw.new('String'),
        Parlour::Types::Generic.new(
          Parlour::Types::Raw.new('Mapper'),
          [
            Parlour::Types::Raw.new('String'),
            Parlour::Types::Raw.new('Integer')
          ]
        )
      ])
    end

    it {
      expect(type.generate_rbi).to eq(
        'Mapper[String, Mapper[String, Integer]]'
      )
    }
    it {
      expect(type.generate_rbs).to eq(
        'Mapper[String, Mapper[String, Integer]]'
      )
    }
    it {
      expect(type.describe).to eq(
        'Mapper<String, Mapper<String, Integer>>'
      )
    }
  end

  describe 'Hash' do
    subject(:type) {
      Parlour::Types::Hash.new('String', 'Integer')
    }

    it { expect(type.key).to eq(Parlour::Types::Raw.new('String')) }
    it { expect(type.value).to eq(Parlour::Types::Raw.new('Integer')) }

    it { expect(type.generate_rbi).to eq('T::Hash[String, Integer]') }
    it { expect(type.generate_rbs).to eq('::Hash[String, Integer]') }
    it { expect(type.describe).to eq('Hash<String, Integer>') }
  end

  describe 'Array' do
    subject(:type) {
      Parlour::Types::Array.new('String')
    }

    it { expect(type.element).to eq(Parlour::Types::Raw.new('String')) }

    it { expect(type.generate_rbi).to eq('T::Array[String]') }
    it { expect(type.generate_rbs).to eq('::Array[String]') }
    it { expect(type.describe).to eq('Array<String>') }
  end

  describe 'Set' do
    subject(:type) {
      Parlour::Types::Set.new('String')
    }

    it { expect(type.element).to eq(Parlour::Types::Raw.new('String')) }

    it { expect(type.generate_rbi).to eq('T::Set[String]') }
    it { expect(type.generate_rbs).to eq('::Set[String]') }
    it { expect(type.describe).to eq('Set<String>') }
  end

  describe 'Proc' do
    subject(:type) {
      Parlour::Types::Proc.new([], 'void')
    }

    it { expect(type.generate_rbi).to eq('T.proc.returns(void)') }
    it { expect(type.generate_rbs).to eq('() -> void') }
    it { expect(type.describe).to eq('() -> void') }
  end

  describe 'Range' do
    subject(:type) {
      Parlour::Types::Range.new('String')
    }

    it { expect(type.element).to eq(Parlour::Types::Raw.new('String')) }

    it { expect(type.generate_rbi).to eq('T::Range[String]') }
    it { expect(type.generate_rbs).to eq('::Range[String]') }
    it { expect(type.describe).to eq('Range<String>') }
  end

  describe 'Enumerable' do
    subject(:type) {
      Parlour::Types::Enumerable.new('String')
    }

    it { expect(type.element).to eq(Parlour::Types::Raw.new('String')) }

    it { expect(type.generate_rbi).to eq('T::Enumerable[String]') }
    it { expect(type.generate_rbs).to eq('::Enumerable[String]') }
    it { expect(type.describe).to eq('Enumerable<String>') }
  end

  describe 'Enumerator' do
    subject(:type) {
      Parlour::Types::Enumerator.new('String')
    }

    it { expect(type.element).to eq(Parlour::Types::Raw.new('String')) }

    it { expect(type.generate_rbi).to eq('T::Enumerator[String]') }
    it { expect(type.generate_rbs).to eq('::Enumerator[String]') }
    it { expect(type.describe).to eq('Enumerator<String>') }
  end
end
