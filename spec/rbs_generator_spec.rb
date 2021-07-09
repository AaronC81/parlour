# typed: ignore
RSpec.describe Parlour::RbsGenerator do
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

  def pa(*a, **kw)
    Parlour::RbsGenerator::Parameter.new(*a, **kw)
  end

  def opts
    Parlour::Options.new(break_params: 4, tab_size: 2, sort_namespaces: false)
  end

  it 'has a root namespace' do
    expect(subject.root).to be_a Parlour::RbsGenerator::Namespace
  end

  context 'module namespace' do
    it 'generates an empty module correctly' do
      mod = subject.root.create_module('Foo')

      expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module Foo
        end
      RUBY
    end
  end

  context 'interface namespace' do
    it 'generates an empty interface correctly' do
      mod = subject.root.create_interface('Foo')

      expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        interface Foo
        end
      RUBY
    end
  end

  context 'class namespace' do
    it 'generates an empty class correctly' do
      klass = subject.root.create_class('Foo')

      expect(klass.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
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

      expect(klass.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
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

    it 'handles includes, extends and constants' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar') do |bar|
          bar.create_extend( 'X')
          bar.create_extend( 'Y')
          bar.create_include( 'Z')
          bar.create_constant('PI', type: 'Integer')
          bar.create_type_alias('Text', type: Parlour::Types::Union.new(['String', 'Symbol']))
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
      end

      expect(klass.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            include Z
            extend X
            extend Y
            type Text = (String | Symbol)
            PI: Integer

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

    it 'handles multiple includes and extends' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_extends(['X', 'Y', 'Z'])
        foo.create_includes(['A', 'B', 'C'])
      end

      expect(klass.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          include A
          include B
          include C
          extend X
          extend Y
          extend Z
        end
      RUBY
    end
  end

  context 'methods' do
    it 'have working equality' do
      expect(subject.root.create_method('foo')).to eq \
        subject.root.create_method('foo')

      expect(subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer', required: false)
      ], 'String')])).to eq subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer', required: false)
      ], 'String')])

      expect(subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer', required: false)
      ], 'String')])).not_to eq subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer', required: true)
      ], 'String')])
    end

    it 'can be created blank' do
      meth = subject.root.create_method('foo')

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def foo: () -> void
      RUBY
    end

    it 'can be created with return types' do
      meth = subject.root.create_method('foo',
        [Parlour::RbsGenerator::MethodSignature.new([], 'String')])

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def foo: () -> String
      RUBY
    end
 
    it 'can be created with parameters' do
      meth = subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer', required: false)
      ], 'String')])

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def foo: (?Integer a) -> String
      RUBY

      meth = subject.root.create_method('bar', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a'),
        pa('b', type: 'String'),
        pa('c', required: false),
        pa('d', type: 'Integer', required: false),
        pa('e', type: Parlour::Types::Record.new({a: 'Integer'}))
      ])])

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def bar: (
                   untyped a,
                   String b,
                   ?untyped c,
                   ?Integer d,
                   { a: Integer } e
                 ) -> void
      RUBY
    end

    it 'supports class methods' do
      meth = subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer', required: false)
      ], 'String')], class_method: true)

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def self.foo: (?Integer a) -> String
      RUBY
    end

    it 'supports type parameters' do
      meth = subject.root.create_method('box', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'A')
      ], 'A', type_parameters: [:A])])

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def box: [A] (A a) -> A
      RUBY
    end

    it 'can be overloaded' do
      meth = subject.root.create_method('foo', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'String')
      ], 'Integer'), Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: Parlour::Types::Boolean.new),
        pa('b', type: 'Integer')
      ], 'String'), Parlour::RbsGenerator::MethodSignature.new([], nil)])

      expect(meth.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        def foo: (String a) -> Integer
               | (bool a, Integer b) -> String
               | () -> void
      RUBY
    end

    it 'return the correct value for #untyped?' do
      meth_a = subject.root.create_method('a', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'Integer')
      ], 'untyped')])
      meth_b = subject.root.create_method('b', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'untyped')
      ], 'Integer')])
      meth_c = subject.root.create_method('c', [Parlour::RbsGenerator::MethodSignature.new([
        pa('a', type: 'untyped')
      ], Parlour::Types::Untyped.new)])

      expect(meth_a.untyped?).to eq false
      expect(meth_b.untyped?).to eq false
      expect(meth_c.untyped?).to eq true
    end
  end

  context 'attributes' do
    it 'can be created using #create_attribute' do
      mod = subject.root.create_module('M') do |m|
        m.create_attribute('r', kind: :reader, type: 'String')
        m.create_attribute('w', kind: :writer, type: 'Integer')
        m.create_attr('a', kind: :accessor, type: Parlour::Types::Boolean.new)
      end

      expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          attr_reader r: String

          attr_writer w: Integer

          attr_accessor a: bool
        end
      RUBY
    end

    it 'can be created using #create_attr_writer etc' do
      mod = subject.root.create_module('M') do |m|
        m.create_attr_reader('r', type: 'String')
        m.create_attr_writer('w', type: 'Integer')
        m.create_attr_accessor('a', type: Parlour::Types::Boolean.new)
      end

      expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          attr_reader r: String

          attr_writer w: Integer

          attr_accessor a: bool
        end
      RUBY
    end
  end

  context 'arbitrary code' do
    it 'is generated correctly for single lines' do
      mod = subject.root.create_module('M') do |m|
        m.create_arbitrary(code: 'some_call')
        m.create_method('foo')
      end

      expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          some_call

          def foo: () -> void
        end
      RUBY
    end

    it 'is generated correctly for multiple lines' do
      mod = subject.root.create_module('M') do |m|
        m.create_arbitrary(code: "foo\nbar\nbaz")
        m.create_method('foo')
      end

      expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          foo
          bar
          baz

          def foo: () -> void
        end
      RUBY
    end
  end

  it 'supports comments' do
    mod = subject.root.create_module('M') do |m|
      m.add_comment('This is a module')
      m.create_class('A') do |a|
        a.add_comment('This is a class')
        a.create_method('foo') do |foo|
          foo.add_comment('This is a method')
        end
      end
    end

    expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a module
      module M
        # This is a class
        class A
          # This is a method
          def foo: () -> void
        end
      end
    RUBY
  end

  it 'supports multi-line comments' do
    mod = subject.root.create_module('M') do |m|
      m.add_comment(['This is a', 'multi-line', 'comment'])
    end

    expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a
      # multi-line
      # comment
      module M
      end
    RUBY
  end

  it 'supports comments on the next child' do
    subject.root.add_comment_to_next_child('This is a module')
    mod = subject.root.create_module('M') do |m|
      m.add_comment('This was added internally')
      m.add_comment_to_next_child('This is a class')
      m.create_class('A') do |a|
        a.add_comment_to_next_child('This is a method')
        a.create_method('foo')
      end
    end

    expect(mod.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a module
      # This was added internally
      module M
        # This is a class
        class A
          # This is a method
          def foo: () -> void
        end
      end
    RUBY
  end

  context '#path' do
    before :all do
      ::PathA = Module.new
      ::PathA::B = Module.new
      ::PathA::B::C = Class.new
    end

    it 'generates correctly' do
      subject.root.path(::PathA::B::C) do |c|
        c.create_method('foo')
      end

      expect(subject.root.generate_rbs(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module PathA
          module B
            class C
              def foo: () -> void
            end
          end
        end
      RUBY
    end

    it 'throws on a non-root namespace' do
      expect { subject.root.create_module('X').path(::PathA::B::C) { |*| } }.to raise_error(RuntimeError)
    end
  end

  it 'supports sorting output' do
    custom_rbs_gen = Parlour::RbsGenerator.new(sort_namespaces: true)
    custom_opts = Parlour::Options.new(
      break_params: 4,
      tab_size: 2,
      sort_namespaces: true
    )

    m = custom_rbs_gen.root.create_module('M')
    m.create_include('Y')
    m.create_module('B')
    m.create_method('c')
    m.create_class('A') do |a|
      a.create_method('c')
      a.create_module('A')
      a.create_class('B')
    end
    m.create_arbitrary(code: '"some arbitrary code"')
    m.create_include('X')
    m.create_arbitrary(code: '"some more"')
    m.create_extend('Z')

    expect(custom_rbs_gen.root.generate_rbs(0, custom_opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      module M
        include X
        include Y
        extend Z

        "some arbitrary code"

        "some more"

        class A
          module A
          end

          class B
          end

          def c: () -> void
        end

        module B
        end

        def c: () -> void
      end
    RUBY
  end
end
