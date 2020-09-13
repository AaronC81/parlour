# typed: ignore
RSpec.describe Parlour::Conversion::RbiToRbs do
  let(:rbi_gen) { Parlour::DetachedRbiGenerator.new }
  let(:rbs_gen) { Parlour::DetachedRbsGenerator.new }
  let(:converter) { described_class.new(rbs_gen) }

  def convert
    rbi_gen.root.children.each do |child|
      converter.convert_object(child, rbs_gen.root)
    end
    rbs_gen.root.children
  end

  it 'converts classes' do
    rbi_gen.root.create_class('Foo')
    rbi_gen.root.create_class('Bar', superclass: 'Foo')
    rbi_gen.root.create_class('Baz', abstract: true)

    foo, bar, baz = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::ClassNamespace) & have_attributes(
      name: 'Foo', superclass: nil, children: [],
    )
    expect(bar).to be_a(Parlour::RbsGenerator::ClassNamespace) & have_attributes(
      name: 'Bar', superclass: 'Foo', children: [],
    )
    expect(baz).to be_a(Parlour::RbsGenerator::ClassNamespace) & have_attributes(
      name: 'Baz', superclass: nil, children: [],
    )
    expect(converter.warnings.length).to eq 1
  end

  it 'converts modules' do
    rbi_gen.root.create_module('Foo')

    foo, bar = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::ModuleNamespace) & have_attributes(
      name: 'Foo', children: [],
    )
  end

  it 'converts interfaces' do
    rbi_gen.root.create_module('Foo', interface: true)

    foo, bar = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::InterfaceNamespace) & have_attributes(
      name: 'Foo', children: [],
    )
  end

  it 'converts namespaces' do
    rbi_gen.root.children << Parlour::RbiGenerator::Namespace.new(rbi_gen)

    foo, = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::Namespace)
    expect(converter.warnings.length).to eq 1
  end

  it 'one-way converts structs' do
    struct = rbi_gen.root.create_struct_class('Foo', props: [
      Parlour::RbiGenerator::StructProp.new('x', 'String'),
      Parlour::RbiGenerator::StructProp.new('y', 'Integer', optional: true),
      Parlour::RbiGenerator::StructProp.new('z', 'Numeric', immutable: true),
    ])

    foo, = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::ClassNamespace) & have_attributes(
      name: 'Foo', children: include(have_attributes(
        name: 'initialize', signatures: [
          have_attributes(
            parameters: [
              have_attributes(name: 'x:', type: 'String'),
              have_attributes(name: 'y:', type: 'Integer', required: false),
              have_attributes(name: 'z:', type: 'Numeric'),
            ],
            return_type: nil,
          )
        ]
      )) & include(have_attributes(
        name: 'x', kind: :accessor, type: 'String'
      )) & include(have_attributes(
        name: 'y', kind: :accessor, type: 'Integer'
      )) & include(have_attributes(
        name: 'z', kind: :reader, type: 'Numeric'
      ))
    )
  end

  it 'doesn\'t convert enums' do
    rbi_gen.root.create_enum_class('Foo')

    expect(convert.length).to eq 0
    expect(converter.warnings.length).to eq 1
  end

  it 'converts constants' do 
    rbi_gen.root.create_constant('FOO', value: 'String')
    rbi_gen.root.create_constant('BAR', value: 'Integer', eigen_constant: true)

    foo, = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::Constant) & have_attributes(
      name: 'FOO', type: 'String',
    )
    expect(converter.warnings.length).to eq 1
  end

  it 'converts attributes' do 
    rbi_gen.root.create_attr_accessor('foo', type: 'String')
    rbi_gen.root.create_attr_reader('bar', type: 'Integer', class_attribute: true)

    foo, = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::Attribute) & have_attributes(
      name: 'foo', type: 'String', kind: :accessor,
    )
    expect(converter.warnings.length).to eq 1
  end

  it 'converts arbitrary' do
    rbi_gen.root.create_arbitrary(code: 'Hello')

    foo, = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::Arbitrary) & have_attributes(code: 'Hello')
    expect(converter.warnings.length).to eq 1
  end

  it 'converts includes and extends' do
    rbi_gen.root.create_include('Foo')
    rbi_gen.root.create_extend('Bar')

    foo, bar = *convert
    expect(foo).to be_a(Parlour::RbsGenerator::Include) & have_attributes(type: 'Foo')
    expect(bar).to be_a(Parlour::RbsGenerator::Extend) & have_attributes(type: 'Bar')
  end

  it 'converts simple methods' do
    rbi_gen.root.create_method('foo')
    rbi_gen.root.create_method('bar', parameters: [
      Parlour::RbiGenerator::Parameter.new('a', type: 'Integer'),
      Parlour::RbiGenerator::Parameter.new('*b', type: 'String'),
    ], return_type: 'Float')

    foo, bar = *convert

    expect(foo).to be_a(Parlour::RbsGenerator::Method) & have_attributes(
      name: 'foo',
      signatures: match_array([
        have_attributes(
          parameters: [],
          return_type: nil,
        )
      ]),
    )

    expect(bar).to be_a(Parlour::RbsGenerator::Method) & have_attributes(
      name: 'bar',
      signatures: match_array([
        have_attributes(
          parameters: match_array([
            have_attributes(name: 'a', type: 'Integer'),
            have_attributes(name: '*b', type: 'String'),
          ]), return_type: 'Float',
        )
      ])
    )
  end

  it 'converts methods with blocks' do
    rbi_gen.root.create_method('foo', parameters: [
      Parlour::RbiGenerator::Parameter.new('a', type: 'Integer'),
      Parlour::RbiGenerator::Parameter.new(
        '&b', type: Parlour::Types::Proc.new(
          [Parlour::Types::Proc::Parameter.new('x', 'String')],
          nil
        )
      )
    ])

    rbi_gen.root.create_method('bar', parameters: [
      Parlour::RbiGenerator::Parameter.new('a', type: 'Integer'),
      Parlour::RbiGenerator::Parameter.new(
        '&b', type: Parlour::Types::Nilable.new(
          Parlour::Types::Proc.new(
            [Parlour::Types::Proc::Parameter.new('x', 'String')],
            nil
          )
        )
      )
    ])

    foo, bar = *convert

    expect(foo).to be_a(Parlour::RbsGenerator::Method) & have_attributes(
      name: 'foo',
      signatures: match_array([
        have_attributes(
          parameters: match_array([
            have_attributes(name: 'a', type: 'Integer'),
          ]),
          return_type: nil,
          block: have_attributes(
            type: have_attributes(
              parameters: match_array([
                have_attributes(
                  name: 'x',
                  type: Parlour::Types::Raw.new('String')
                ),
              ]),
              return_type: nil,
            ),
            required: true,
          )
        )
      ]),
    )

    expect(bar).to be_a(Parlour::RbsGenerator::Method) & have_attributes(
      name: 'bar',
      signatures: match_array([
        have_attributes(
          parameters: match_array([
            have_attributes(name: 'a', type: 'Integer'),
          ]),
          return_type: nil,
          block: have_attributes(
            type: have_attributes(
              parameters: match_array([
                have_attributes(
                  name: 'x',
                  type: Parlour::Types::Raw.new('String')
                ),
              ]),
              return_type: nil,
            ),
            required: false,
          )
        )
      ]),
    )
  end
end