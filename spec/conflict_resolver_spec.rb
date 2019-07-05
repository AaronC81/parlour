RSpec.describe Parlour::ConflictResolver do
  def gen
    Parlour::RbiGenerator.new
  end

  def pa(*a)
    Parlour::RbiGenerator::Parameter.new(*a)
  end

  context 'when resolving conflicts on methods' do
    it 'merges multiple of the same method definition' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', [
          pa('a', type: 'String')
        ], nil)
        a.create_method('foo', [
          pa('a', type: 'String')
        ], nil)
      end

      expect(a.children.length).to be 2

      subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

      expect(a.children.length).to be 1
    end

    it 'will not merge methods with different names' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', [], nil)
        a.create_method('bar', [], nil)
      end

      expect(a.children.length).to be 2

      subject.resolve_conflicts(a) { |*| raise 'unable to resolve automatically' }

      expect(a.children.length).to be 2
    end

    it 'will not attempt to automatically merge conflicting methods' do
      a = gen.root.create_class('A') do |a|
        a.create_method('foo', [
          pa('a', type: 'String')
        ], nil)
        a.create_method('foo', [
          pa('a', type: 'Integer')
        ], nil)
      end

      expect(a.children.length).to be 2

      invocations = 0

      subject.resolve_conflicts(a) { |*| invocations += 1; nil }

      expect(invocations).to be 1
      expect(a.children.length).to be 0 # the block returned nil, so both deleted
    end
  end
end