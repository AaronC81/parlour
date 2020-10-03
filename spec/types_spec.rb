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
end
