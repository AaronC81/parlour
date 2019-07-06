RSpec.describe Parlour::RbiGenerator do
  def fix_heredoc(x)
    lines = x.lines
    /^( *)/ === lines.first
    indent_amount = $1.length
    lines.map do |line|
      /^ +$/ === line[0...indent_amount] \
        ? line[indent_amount..-1]
        : line
    end.join.rstrip
  end

  def pa(*a)
    Parlour::RbiGenerator::Parameter.new(*a)
  end

  def opts
    Parlour::RbiGenerator::Options.new(break_params: 4, tab_size: 2)
  end

  it 'has a root namespace' do
    expect(subject.root).to be_a Parlour::RbiGenerator::Namespace
  end

  context 'module namespace' do
    it 'generates an empty module correctly' do
      mod = subject.root.create_module('Foo')

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module Foo
        end
      RUBY
    end
  end

  context 'class namespace' do
    it 'generates an empty class correctly' do
      klass = subject.root.create_class('Foo')

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
        end
      RUBY
    end

    it 'nests classes correctly' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar') do |bar|
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
        foo.create_class('Baz') do |baz|
          baz.create_class('A')
          baz.create_class('B')
          baz.create_class('C')
        end
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            class A
            end

            class B
            end

            class C
            end
          end

          class Baz
            class A
            end

            class B
            end

            class C
            end
          end
        end
      RUBY
    end

    it 'handles abstract' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar', abstract: true) do |bar|
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            abstract!

            class A
            end

            class B
            end

            class C
            end
          end
        end
      RUBY
    end

    it 'handles includes and extends' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar', abstract: true) do |bar|
          bar.add_extend('X')
          bar.add_extend('Y')
          bar.add_include('Z')
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            abstract!

            include Z
            extend X
            extend Y

            class A
            end

            class B
            end

            class C
            end
          end
        end
      RUBY
    end
  end

  context 'methods' do
    it 'have working equality' do
      expect(subject.root.create_method('foo', [], nil)).to eq \
        subject.root.create_method('foo', [], nil)

      expect(subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '4')
      ], 'String')).to eq subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '4')
      ], 'String')

      expect(subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '4')
      ], 'String')).not_to eq subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '5')
      ], 'String')
    end

    it 'can be created blank' do
      meth = subject.root.create_method('foo', [], nil)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { void }
        def foo; end
      RUBY
    end

    it 'can be created with return types' do
      meth = subject.root.create_method('foo', [], 'String')

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { returns(String) }
        def foo; end
      RUBY
    end

    it 'can be created with parameters' do
      meth = subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '4')
      ], 'String')

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { params(a: Integer).returns(String) }
        def foo(a = 4); end
      RUBY

      meth = subject.root.create_method('bar', [
        pa('a'),
        pa('b', type: 'String'),
        pa('c', default: '3'),
        pa('d', type: 'Integer', default: '4')
      ], nil)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig do
          params(
            a: T.untyped,
            b: String,
            c: T.untyped,
            d: Integer,
          ).void
        end
        def bar(a, b, c = 3, d = 4); end
      RUBY
    end

    it 'can be created with qualifiers' do
      meth = subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '4')
      ], 'String', implementation: true, overridable: true)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { implementation.overridable.params(a: Integer).returns(String) }
        def foo(a = 4); end
      RUBY
    end

    it 'supports class methods' do
      meth = subject.root.create_method('foo', [
        pa('a', type: 'Integer', default: '4')
      ], 'String', class_method: true)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { params(a: Integer).returns(String) }
        def self.foo(a = 4); end
      RUBY
    end
  end

  context 'attributes' do
    it 'can be created using #create_attribute' do
      mod = subject.root.create_module('M') do |m|
        m.create_attribute('r', :reader, 'String')
        m.create_attribute('w', :writer, 'Integer')
        m.create_attr('a', :accessor, 'T::Boolean') # test alias too
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          sig { returns(String) }
          attr_reader :r

          sig { params(w: Integer).returns(Integer) }
          attr_writer :w

          sig { returns(T::Boolean) }
          attr_accessor :a
        end
      RUBY
    end

    it 'can be created using #create_attr_writer etc' do
      mod = subject.root.create_module('M') do |m|
        m.create_attr_reader('r', 'String')
        m.create_attr_writer('w', 'Integer')
        m.create_attr_accessor('a', 'T::Boolean')
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          sig { returns(String) }
          attr_reader :r

          sig { params(w: Integer).returns(Integer) }
          attr_writer :w

          sig { returns(T::Boolean) }
          attr_accessor :a
        end
      RUBY
    end
  end

  it 'supports comments' do
    mod = subject.root.create_module('M') do |m|
      m.add_comment('This is a module')
      m.create_class('A') do |a|
        a.add_comment('This is a class')
        a.create_method('foo', [], nil) do |foo|
          foo.add_comment('This is a method')
        end
      end
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a module
      module M
        # This is a class
        class A
          # This is a method
          sig { void }
          def foo; end
        end
      end
    RUBY
  end

  it 'supports multi-line comments' do
    mod = subject.root.create_module('M') do |m|
      m.add_comment(['This is a', 'multi-line', 'comment'])
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a
      # multi-line
      # comment
      module M
      end
    RUBY
  end
end
