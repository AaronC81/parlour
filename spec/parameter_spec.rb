RSpec.describe Parlour::RbiGenerator::Parameter do
  def pa(*a)
    described_class.new(*a)
  end

  it 'determines kinds properly' do
    expect(pa('foo').kind).to eq :normal
    expect(pa('*foo').kind).to eq :splat
    expect(pa('**foo').kind).to eq :double_splat
    expect(pa('&foo').kind).to eq :block
    expect(pa('foo:').kind).to eq :keyword
  end

  it 'determines #name_without_kind properly' do
    expect(pa('foo').name_without_kind).to eq 'foo'
    expect(pa('*foo').name_without_kind).to eq 'foo'
    expect(pa('**foo').name_without_kind).to eq 'foo'
    expect(pa('&foo').name_without_kind).to eq 'foo'
    expect(pa('foo:').name_without_kind).to eq 'foo'
  end

  it 'can generate definitions' do
    expect(pa('foo').to_def_param).to eq 'foo'
    expect(pa('*foo').to_def_param).to eq '*foo'
    expect(pa('**foo').to_def_param).to eq '**foo'
    expect(pa('&foo').to_def_param).to eq '&foo'
    expect(pa('foo:').to_def_param).to eq 'foo:'

    expect(pa('foo', default: 3).to_def_param).to eq 'foo = 3'
    expect(pa('foo:', default: 3).to_def_param).to eq 'foo: 3'
  end

  it 'can generate signatures' do
    expect(pa('foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('*foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('**foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('&foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('foo:').to_sig_param).to eq 'foo: T.untyped'

    expect(pa('foo', type: 'Integer', default: '3').to_sig_param).to eq 'foo: Integer'
  end

  it 'uses the input type for default values' do
    expect(pa('foo:', default: '3').to_def_param).to eq "foo: '3'"
    expect(pa('foo:', default: 3).to_def_param).to eq "foo: 3"
    expect(pa('foo:', default: :symbol).to_def_param).to eq "foo: :symbol"
    expect(pa('foo:', default: 'nil').to_def_param).to eq "foo: nil"
  end
end
