RSpec.describe Parlour::ConflictResolver do
  def gen
    Parlour::RbiGenerator.new
  end

  def pa(*a)
    Parlour::RbiGenerator::Parameter.new(*a)
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

    it 'will not merge methods with different names' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo')
        a.create_method('bar')
      end

      expect(a.children.length).to be 2

      subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

      expect(a.children.length).to be 2
    end

    it 'will not attempt to automatically merge conflicting methods' do
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
end