RSpec.describe Parlour::ConflictResolver do
  def gen
    Parlour::RbiGenerator.new
  end

  def pa(*a, **kw)
    Parlour::RbiGenerator::Parameter.new(*a, **kw)
  end

  it 'does not merge different kinds of definition' do
    m = gen.root.create_module('M') do |m|
      m.create_module('A')
      m.create_class('A')
    end

    expect(m.children.length).to be 2

    invocations = 0
    subject.resolve_conflicts(m) { |*| invocations += 1; nil }

    expect(invocations).to be 1
    expect(m.children.length).to be 0
  end

  context 'when resolving conflicts on methods' do
    it 'merges multiple of the same method definition' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', parameters: [pa('a', type: 'String')])
        a.create_method('foo', parameters: [pa('a', type: 'String')])
      end

      expect(a.children.length).to be 2

      subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

      expect(a.children.length).to be 1
    end

    it 'merges methods with same parameters where one is T.untyped and the other is nil' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', parameters: [pa('a', type: 'T.untyped')])
        a.create_method('foo', parameters: [pa('a', type: nil)])
      end

      expect(a.children.length).to be 2

      subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

      expect(a.children.length).to be 1
    end

    it 'will not merge methods with different names' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo')
        a.create_method('bar')
      end

      expect(a.children.length).to be 2

      subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

      expect(a.children.length).to be 2
    end

    it 'does not merge methods with different parameter types' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', parameters: [pa('a', type: 'String')])
        a.create_method('foo', parameters: [pa('a', type: 'Integer')])
      end

      expect(a.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(a) { |*| invocations += 1; nil }

      expect(invocations).to be 1
      expect(a.children.length).to be 0
    end

    it 'does not merge methods with different parameter types when one is nil' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', parameters: [pa('a', type: 'String')])
        a.create_method('foo', parameters: [pa('a', type: nil)])
      end

      expect(a.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(a) { |*| invocations += 1; nil }

      expect(invocations).to be 1
      expect(a.children.length).to be 0
    end
  end

  context 'when resolving conflicts on classes' do
    it 'merges identical empty classes' do
      m = gen.root.create_module('M') do |m|
        m.create_class('A')
        m.create_class('A')
      end

      expect(m.children.length).to be 2

      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(m.children.first.name).to eq 'A'
    end

    it 'does not merge empty classes with conflicting signatures' do
      m = gen.root.create_module('M') do |m|
        m.create_class('A', abstract: true)
        m.create_class('A')
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(invocations).to be 1
      expect(m.children.length).to be 0
    end

    it 'merges definitions inside compatible classes' do
      m = gen.root.create_module('M') do |m|
        m.create_class('A') do |a|
          a.create_extend('E1')
          a.create_include('I1')
          a.create_method('foo')
        end
        m.create_class('A') do |a|
          a.create_extend('E2')
          a.create_include('I2')
          a.create_method('bar')
        end
      end

      expect(m.children.length).to be 2

      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      a = m.children.first
      expect(a.children.map(&:name)).to contain_exactly('foo', 'bar', 'I1', 'I2', 'E1', 'E2')
      expect(a.includes.map(&:name)).to contain_exactly('I1', 'I2')
      expect(a.extends.map(&:name)).to contain_exactly('E1', 'E2')
    end

    it 'merges compatible superclasses' do
      m = gen.root.create_module('M') do |m|
        m.create_class('A', superclass: 'X')
        m.create_class('A')
        m.create_class('A', superclass: 'X')
      end

      expect(m.children.length).to be 3

      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(m.children.first.name).to eq 'A'
      expect(m.children.first.superclass).to eq 'X'
    end

    it 'does not merge incompatible superclasses' do
      m = gen.root.create_module('M') do |m|
        m.create_class('A', superclass: 'X')
        m.create_class('A')
        m.create_class('A', superclass: 'Y')
      end

      expect(m.children.length).to be 3

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(m.children.length).to be 0
      expect(invocations).to be 1
    end

    it 'preserves methods and class methods with the same name' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', class_method: true)
        a.create_method('foo')
      end

      expect(a.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(a) { |*| invocations += 1; nil }

      expect(a.children.length).to be 2
      expect(invocations).to be 0
    end
  end

  context 'when resolving conflicts on enums' do
    it 'merges enums with identical values' do
      m = gen.root.create_module('M') do |m|
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0
    end

    it 'merges enums with identical values in different order' do
      m = gen.root.create_module('M') do |m|
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
        m.create_enum_class('Direction', enums: ['East', 'West', 'North', 'South'])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0
    end

    it 'merges enums with some value and no value' do
      m = gen.root.create_module('M') do |m|
        m.create_enum_class('Direction', enums: [])
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0

      expect(m.children.first.enums).to eq(['North', 'South', 'East', 'West'])
    end

    it 'does not merge enums with different values' do
      m = gen.root.create_module('M') do |m|
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
        m.create_enum_class('Direction', enums: ['Northeast', 'Southeast', 'Southwest', 'Northwest'])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(m.children.length).to be 0
      expect(invocations).to be 1
    end

    it 'merges enums and classes' do
      m = gen.root.create_module('M') do |m|
        m.create_class('Direction')
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0

      expect(m.children.first.enums).to eq(['North', 'South', 'East', 'West'])
    end

    it 'does not merge non-mergeable enums and classes' do
      m = gen.root.create_module('M') do |m|
        m.create_class('Direction')
        m.create_enum_class('Direction', enums: ['North', 'South', 'East', 'West'])
        m.create_enum_class('Direction', enums: ['Northeast', 'Southeast', 'Southwest', 'Northwest'])
      end

      expect(m.children.length).to be 3

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(m.children.length).to be 0
      expect(invocations).to be 1
    end
  end

  context 'when resolving conflicts on structs' do
    it 'merges structs with identical values' do
      m = gen.root.create_module('M') do |m|
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'String')])
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'String')])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0
    end

    it 'merges structs with identical values in different order' do
      m = gen.root.create_module('M') do |m|
        props = [
          Parlour::RbiGenerator::StructProp.new('name', 'String'),
          Parlour::RbiGenerator::StructProp.new('age', 'Integer'),
        ]
        m.create_struct_class('Person', props: props)
        m.create_struct_class('Person', props: props.reverse)
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0
    end

    it 'merges structs with some value and no value' do
      m = gen.root.create_module('M') do |m|
        m.create_struct_class('Person', props: [])
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'String')])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0

      expect(m.children.first.props.map(&:name)).to eq(['name'])
    end

    it 'does not merge struct with different value' do
      m = gen.root.create_module('M') do |m|
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'String')])
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'Integer')])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(m.children.length).to be 0
      expect(invocations).to be 1
    end

    it 'merges enums and classes' do
      m = gen.root.create_module('M') do |m|
        m.create_class('Person')
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'String')])
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(invocations).to be 0

      expect(m.children.first.props.map(&:name)).to eq(['name'])
    end

    it 'does not merge non-mergeable structs and classes' do
      m = gen.root.create_module('M') do |m|
        m.create_class('Person')
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'String')])
        m.create_struct_class('Person', props: [Parlour::RbiGenerator::StructProp.new('name', 'Integer')])
      end

      expect(m.children.length).to be 3

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(m.children.length).to be 0
      expect(invocations).to be 1
    end
  end

  context 'when resolving conflicts on modules' do
    it 'merges identical empty modules' do
      m = gen.root.create_module('M') do |m|
        m.create_module('A')
        m.create_module('A')
      end

      expect(m.children.length).to be 2

      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      expect(m.children.first.name).to eq 'A'
    end

    it 'does not merge empty modules with conflicting signatures' do
      m = gen.root.create_module('M') do |m|
        m.create_module('A', interface: true)
        m.create_module('A')
      end

      expect(m.children.length).to be 2

      invocations = 0
      subject.resolve_conflicts(m) { |*| invocations += 1; nil }

      expect(invocations).to be 1
      expect(m.children.length).to be 0
    end

    it 'merges definitions inside compatible modules' do
      m = gen.root.create_module('M') do |m|
        m.create_module('A') do |a|
          a.create_extend('E1')
          a.create_include('I1')
          a.create_method('foo')
        end
        m.create_module('A') do |a|
          a.create_extend('E2')
          a.create_include('I2')
          a.create_method('bar')
        end
      end

      expect(m.children.length).to be 2

      subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

      expect(m.children.length).to be 1
      a = m.children.first
      expect(a.children.map(&:name)).to contain_exactly('foo', 'bar', 'I1', 'I2', 'E1', 'E2')
      expect(a.includes.map(&:name)).to contain_exactly('I1', 'I2')
      expect(a.extends.map(&:name)).to contain_exactly('E1', 'E2')
    end
  end

  context 'when loading from source' do
    it 'allows specialized classes (structs/enums) to have namespace children' do
      x = Parlour::TypeLoader.load_source(<<-RUBY)
        class A < T::Struct
          prop :x, String
        end
        class A::B; end
        class A
          class C; end
        end
        class A < T::Struct; end

        class Z < T::Enum
          enums do
            North = new
          end
        end
        class Z::Y; end
        class Z
          class X; end
        end
        class Z < T::Enum; end
      RUBY

      expect(x.children.length).to be 8

      subject.resolve_conflicts(x) { |*x| raise 'unable to resolve automatically' }

      expect(x.children.length).to be 2
    end

    it 'allows specialized classes (structs/enums) to be class namespaces' do
      x = Parlour::TypeLoader.load_source(<<-RUBY)
        class A < T::Struct; end
        class A; end

        class Z < T::Enum; end
        class Z; end
      RUBY

      expect(x.children.length).to be 4

      subject.resolve_conflicts(x) { |*x| raise 'unable to resolve automatically' }

      expect(x.children.length).to be 2
    end

    it 'resolves conflicts regardless of order' do
      x = Parlour::TypeLoader.load_source(<<~RUBY)
        module Outer
          class A < T::Struct; end
          class A; end

          class B::C
          end

          module B
            class D; end
          end

          class Z < T::Enum; end
          class Z; end
        end
      RUBY

      expected_rbi = <<~RUBY.strip
        module Outer
        end
        
        class Outer::A < T::Struct

        end

        module Outer::B
        end
        
        class Outer::B::D
        end
        
        class Outer::B::C
        end

        class Outer::Z < T::Enum
          enums do
          end

        end
      RUBY

      subject.resolve_conflicts(x) { |*x| raise 'unable to resolve automatically' }

      actual_rbi = x.generate_rbi(
        0,
        Parlour::Options.new(break_params: 4, tab_size: 2, sort_namespaces: true)
      ).join("\n")

      expect(actual_rbi).to eq (expected_rbi)
    end
  end

  it 'handles nested conflicts' do
    m = gen.root.create_module('M') do |m|
      m.create_module('A') do |a|
        a.create_method('foo')
      end
      m.create_module('A') do |a|
        a.create_method('foo')
      end
    end

    expect(m.children.length).to be 2

    subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

    expect(m.children.length).to be 1
    expect(m.children.first.children.length).to be 1
    expect(m.children.first.children.first.name).to eq 'foo'
  end

  it 'does not conflict between instance attributes and class attributes' do
    a = gen.root.create_class('A') do |a|
      a.create_attr_accessor('foo', type: 'String', class_attribute: true)
      a.create_attr_accessor('foo', type: 'String')
    end

    expect(a.children.length).to be 2

    subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

    expect(a.children.length).to be 2
  end

  it 'does not raise a conflict if a method and namespace share the same name' do
    a = gen.root.create_class('A') do |a|
      a.create_class('B')
      a.create_method('B', class_method: true)
    end

    expect(a.children.length).to be 2

    subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

    expect(a.children.length).to be 2
  end

  it 'does not consider includes to conflict with sibling namespaces' do
    x = gen.root.create_module('X') do |x|
      x.create_module('A')
      x.create_includes(['A'])
    end

    expect(x.children.length).to be 2

    subject.resolve_conflicts(x) { |*| raise 'unable to resolve automatically' }

    expect(x.children.length).to be 2
  end

  it 'should deduplicate multiple includes on the same module' do
    m = gen.root.create_module('M') do |m|
      m.create_include('I1')
      m.create_include('I2')
      m.create_include('I1')
      m.create_include('I1')
      m.create_include('I1')
    end

    expect(m.children.length).to be 5

    subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

    expect(m.children.length).to be 2
  end

  it 'should deduplicate multiple extends on the same module' do
    m = gen.root.create_module('M') do |m|
      m.create_extend('I1')
      m.create_extend('I2')
      m.create_extend('I1')
      m.create_extend('I1')
      m.create_extend('I1')
    end

    expect(m.children.length).to be 5

    subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

    expect(m.children.length).to be 2
  end

  it 'should deduplicate multiple extends and multipe includes on the same module' do
    m = gen.root.create_module('M') do |m|
      m.create_extend('I1')
      m.create_extend('I2')
      m.create_extend('I1')
      m.create_extend('I1')
      m.create_include('I1')
      m.create_include('I1')
      m.create_include('I1')
    end

    expect(m.children.length).to be 7

    subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

    expect(m.children.length).to be 3
  end

  it 'should deduplicate multiple extends and multipe includes on the different modules' do
    m = gen.root.create_module('M') do |m|
      m.create_extend('I1')
      m.create_extend('I2')
      m.create_extend('I1')
      m.create_extend('I1')
      m.create_include('J1')
      m.create_include('J1')
      m.create_include('J1')
    end

    expect(m.children.length).to be 7

    subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

    expect(m.children.length).to be 3
  end

  it 'should deduplicate multiple extends and multipe includes on multiple different modules' do
    m = gen.root.create_module('M') do |m|
      m.create_extend('I1')
      m.create_extend('I2')
      m.create_extend('I1')
      m.create_extend('I1')
      m.create_include('I1')
      m.create_include('I1')
      m.create_include('I2')
    end

    expect(m.children.length).to be 7

    subject.resolve_conflicts(m) { |*| raise 'unable to resolve automatically' }

    expect(m.children.length).to be 4
  end

  it 'does not conflict writers with non-=-suffixed methods' do
    x = Parlour::TypeLoader.load_source(<<-RUBY).children.first
      class A
        attr_writer :foo
        def foo; end
      end
    RUBY

    expect(x.children.length).to be 2

    subject.resolve_conflicts(x) { |*| raise 'unable to resolve automatically' }

    expect(x.children.length).to be 2
  end
end
