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

    expect(pa('foo', default: '3').to_def_param).to eq 'foo = 3'
    expect(pa('foo:', default: '3').to_def_param).to eq 'foo: 3'
  end

  it 'can generate signatures' do
    expect(pa('foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('*foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('**foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('&foo').to_sig_param).to eq 'foo: T.untyped'
    expect(pa('foo:').to_sig_param).to eq 'foo: T.untyped'

    expect(pa('foo', type: 'Integer', default: '3').to_sig_param).to eq 'foo: Integer'
  end

  it 'can generate various types of defaults' do
    expect(pa('foo:', default: '5').to_def_param).to eq 'foo: 5'
    expect(pa('foo:', default: "'bar'").to_def_param).to eq "foo: 'bar'"
    expect(pa('foo:', default: '\'bar\'').to_def_param).to eq "foo: 'bar'"
    expect(pa('foo:', default: ':bar').to_def_param).to eq "foo: :bar"
    expect(pa('foo:', default: ":'bar'").to_def_param).to eq "foo: :'bar'"
    expect(pa('foo:', default: 'nil').to_def_param).to eq "foo: nil"
    expect(pa('foo:', default: '3.14159').to_def_param).to eq "foo: 3.14159"
    expect(pa('foo:', default: 'true').to_def_param).to eq "foo: true"
    expect(pa('foo:', default: '{ key: "value", key2: "value" }').to_def_param).to eq 'foo: { key: "value", key2: "value" }'
    expect(pa('foo:', default: '[1, 2, 3]').to_def_param).to eq 'foo: [1, 2, 3]'
  end
end
