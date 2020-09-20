# typed: strong
module Kernel
end

module Parlour
  VERSION = '4.0.1'

  class ConflictResolver
    extend T::Sig

    sig { params(namespace: RbiGenerator::Namespace, resolver: T.proc.params(
          desc: String,
          choices: T::Array[RbiGenerator::RbiObject]
        ).returns(T.nilable(RbiGenerator::RbiObject))).void }
    def resolve_conflicts(namespace, &resolver); end

    sig { params(arr: T::Array[T.untyped]).returns(T.nilable(Symbol)) }
    def merge_strategy(arr); end

    sig { params(arr: T::Array[T.untyped]).returns(T::Boolean) }
    def all_eql?(arr); end

    sig { params(namespace: RbiGenerator::Namespace, name: T.nilable(String)).void }
    def deduplicate_mixins_of_name(namespace, name); end
  end

  module Debugging
    extend T::Sig

    sig { params(value: T::Boolean).returns(T::Boolean) }
    def self.debug_mode=(value); end

    sig { returns(T::Boolean) }
    def self.debug_mode?; end

    sig { params(object: T.untyped, message: String).void }
    def self.debug_puts(object, message); end

    sig { params(object: T.untyped).returns(String) }
    def self.name_for_debug_caller(object); end

    module Tree
      extend T::Sig
      INDENT_SPACES = 2

      sig { params(message: String).returns(String) }
      def self.begin(message); end

      sig { params(message: String).returns(String) }
      def self.here(message); end

      sig { params(message: String).returns(String) }
      def self.end(message); end

      sig { returns(T.untyped) }
      def self.line_prefix; end

      sig { returns(T.untyped) }
      def self.text_prefix; end
    end
  end

  class ParseError < StandardError
    extend T::Sig

    sig { returns(Parser::Source::Buffer) }
    attr_reader :buffer

    sig { returns(Parser::Source::Range) }
    attr_reader :range

    sig { params(buffer: T.untyped, range: T.untyped).returns(T.untyped) }
    def initialize(buffer, range); end
  end

  class Plugin
    abstract!

    extend T::Sig
    extend T::Helpers

    sig { returns(T::Hash[String, T.class_of(Plugin)]) }
    def self.registered_plugins; end

    sig { params(new_plugin: T.class_of(Plugin)).void }
    def self.inherited(new_plugin); end

    sig { params(plugins: T::Array[Plugin], generator: RbiGenerator, allow_failure: T::Boolean).void }
    def self.run_plugins(plugins, generator, allow_failure: true); end

    sig { params(options: T::Hash[T.untyped, T.untyped]).void }
    def initialize(options); end

    sig { abstract.params(root: RbiGenerator::Namespace).void }
    def generate(root); end

    sig { returns(T.nilable(String)) }
    attr_accessor :strictness
  end

  module TypeLoader
    extend T::Sig

    sig { params(source: String, filename: T.nilable(String), generator: T.nilable(RbiGenerator)).returns(RbiGenerator::Namespace) }
    def self.load_source(source, filename = nil, generator: nil); end

    sig { params(filename: String, generator: T.nilable(RbiGenerator)).returns(RbiGenerator::Namespace) }
    def self.load_file(filename, generator: nil); end

    sig do
      params(
        root: String,
        inclusions: T::Array[String],
        exclusions: T::Array[String],
        generator: T.nilable(RbiGenerator)
      ).returns(RbiGenerator::Namespace)
    end
    def self.load_project(root, inclusions: ['.'], exclusions: [], generator: nil); end
  end

  class TypeParser
    extend T::Sig

    class NodePath
      extend T::Sig

      sig { returns(T::Array[Integer]) }
      attr_reader :indices

      sig { params(indices: T::Array[Integer]).void }
      def initialize(indices); end

      sig { returns(NodePath) }
      def parent; end

      sig { params(index: Integer).returns(NodePath) }
      def child(index); end

      sig { params(offset: Integer).returns(NodePath) }
      def sibling(offset); end

      sig { params(start: Parser::AST::Node).returns(Parser::AST::Node) }
      def traverse(start); end
    end

    sig { params(ast: Parser::AST::Node, unknown_node_errors: T::Boolean, generator: T.nilable(RbiGenerator)).void }
    def initialize(ast, unknown_node_errors: false, generator: nil); end

    sig { params(filename: String, source: String, generator: T.nilable(RbiGenerator)).returns(TypeParser) }
    def self.from_source(filename, source, generator: nil); end

    sig { returns(Parser::AST::Node) }
    attr_accessor :ast

    sig { returns(T::Boolean) }
    attr_reader :unknown_node_errors

    sig { returns(RbiGenerator) }
    attr_accessor :generator

    sig { returns(RbiGenerator::Namespace) }
    def parse_all; end

    sig { params(path: NodePath, is_within_eigenclass: T::Boolean).returns(T::Array[RbiGenerator::RbiObject]) }
    def parse_path_to_object(path, is_within_eigenclass: false); end

    class IntermediateSig < T::Struct
      prop :type_parameters, T.nilable(T::Array[Symbol])
      prop :overridable, T::Boolean
      prop :override, T::Boolean
      prop :abstract, T::Boolean
      prop :final, T::Boolean
      prop :return_type, T.nilable(String)
      prop :params, T.nilable(T::Array[Parser::AST::Node])

    end

    sig { params(path: NodePath).returns(IntermediateSig) }
    def parse_sig_into_sig(path); end

    sig { params(path: NodePath, is_within_eigenclass: T::Boolean).returns(T::Array[RbiGenerator::Method]) }
    def parse_sig_into_methods(path, is_within_eigenclass: false); end

    sig { params(path: NodePath, is_within_eigenclass: T::Boolean).returns(T::Array[RbiGenerator::Method]) }
    def parse_method_into_methods(path, is_within_eigenclass: false); end

    sig { params(node: T.nilable(Parser::AST::Node)).returns(T::Array[Symbol]) }
    def constant_names(node); end

    sig { params(node: Parser::AST::Node).returns(T::Boolean) }
    def sig_node?(node); end

    sig { params(path: NodePath).returns(T::Boolean) }
    def previous_sibling_sig_node?(path); end

    sig { params(node: T.nilable(Parser::AST::Node)).returns(T.nilable(String)) }
    def node_to_s(node); end

    sig { params(node: T.nilable(Parser::AST::Node), modifier: Symbol).returns(T::Boolean) }
    def body_has_modifier?(node, modifier); end

    sig { params(node: Parser::AST::Node).returns([T::Array[String], T::Array[String]]) }
    def body_includes_and_extends(node); end

    sig { params(desc: String, node: T.any(Parser::AST::Node, NodePath)).returns(T.noreturn) }
    def parse_err(desc, node); end

    sig do
      type_parameters(:A, :B).params(
        a: T::Array[T.type_parameter(:A)],
        fa: T.proc.params(item: T.type_parameter(:A)).returns(T.untyped),
        b: T::Array[T.type_parameter(:B)],
        fb: T.proc.params(item: T.type_parameter(:B)).returns(T.untyped)
      ).returns(T::Array[[T.type_parameter(:A), T.type_parameter(:B)]])
    end
    def zip_by(a, fa, b, fb); end
  end

  class RbiGenerator
    extend T::Sig

    sig { params(break_params: Integer, tab_size: Integer, sort_namespaces: T::Boolean).void }
    def initialize(break_params: 4, tab_size: 2, sort_namespaces: false); end

    sig { returns(Options) }
    attr_reader :options

    sig { returns(Namespace) }
    attr_reader :root

    sig { returns(T.nilable(Plugin)) }
    attr_accessor :current_plugin

    sig { overridable.params(strictness: String).returns(String) }
    def rbi(strictness = 'strong'); end

    class Arbitrary < RbiObject
      sig { params(generator: RbiGenerator, code: String, block: T.nilable(T.proc.params(x: Arbitrary).void)).void }
      def initialize(generator, code: '', &block); end

      sig { returns(String) }
      attr_accessor :code

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end
    end

    class Attribute < Method
      sig do
        params(
          generator: RbiGenerator,
          name: String,
          kind: Symbol,
          type: String,
          class_attribute: T::Boolean,
          block: T.nilable(T.proc.params(x: Attribute).void)
        ).void
      end
      def initialize(generator, name, kind, type, class_attribute: false, &block); end

      sig { returns(Symbol) }
      attr_reader :kind

      sig { returns(T::Boolean) }
      attr_reader :class_attribute

      sig { override.params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_definition(indent_level, options); end
    end

    class ClassNamespace < Namespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).void
      end
      def initialize(generator, name, final, superclass, abstract, &block); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { returns(T.nilable(String)) }
      attr_reader :superclass

      sig { returns(T::Boolean) }
      attr_reader :abstract

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end
    end

    class Constant < RbiObject
      sig do
        params(
          generator: RbiGenerator,
          name: String,
          value: String,
          eigen_constant: T::Boolean,
          block: T.nilable(T.proc.params(x: Constant).void)
        ).void
      end
      def initialize(generator, name: '', value: '', eigen_constant: false, &block); end

      sig { returns(String) }
      attr_reader :value

      sig { returns(T.untyped) }
      attr_reader :eigen_constant

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end
    end

    class EnumClassNamespace < ClassNamespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          enums: T::Array[T.any([String, String], String)],
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: EnumClassNamespace).void)
        ).void
      end
      def initialize(generator, name, final, enums, abstract, &block); end

      sig { returns(T::Array[T.any([String, String], String)]) }
      attr_reader :enums

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_body(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end
    end

    class Extend < RbiObject
      sig { params(generator: RbiGenerator, name: String, block: T.nilable(T.proc.params(x: Extend).void)).void }
      def initialize(generator, name: '', &block); end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end
    end

    class Include < RbiObject
      sig { params(generator: RbiGenerator, name: String, block: T.nilable(T.proc.params(x: Include).void)).void }
      def initialize(generator, name: '', &block); end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end
    end

    class Method < RbiObject
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          parameters: T::Array[Parameter],
          return_type: T.nilable(String),
          abstract: T::Boolean,
          implementation: T::Boolean,
          override: T::Boolean,
          overridable: T::Boolean,
          class_method: T::Boolean,
          final: T::Boolean,
          type_parameters: T.nilable(T::Array[Symbol]),
          block: T.nilable(T.proc.params(x: Method).void)
        ).void
      end
      def initialize(generator, name, parameters, return_type = nil, abstract: false, implementation: false, override: false, overridable: false, class_method: false, final: false, type_parameters: nil, &block); end

      sig { overridable.params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { returns(T::Array[Parameter]) }
      attr_reader :parameters

      sig { returns(T.nilable(String)) }
      attr_reader :return_type

      sig { returns(T::Boolean) }
      attr_reader :abstract

      sig { returns(T::Boolean) }
      attr_reader :implementation

      sig { returns(T::Boolean) }
      attr_reader :override

      sig { returns(T::Boolean) }
      attr_reader :overridable

      sig { returns(T::Boolean) }
      attr_reader :class_method

      sig { returns(T::Boolean) }
      attr_reader :final

      sig { returns(T::Array[Symbol]) }
      attr_reader :type_parameters

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end

      sig { overridable.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_definition(indent_level, options); end

      sig { returns(String) }
      def qualifiers; end
    end

    class ModuleNamespace < Namespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          interface: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).void
      end
      def initialize(generator, name, final, interface, &block); end

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { returns(T::Boolean) }
      attr_reader :interface

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.returns(String) }
      def describe; end
    end

    class Namespace < RbiObject
      extend T::Sig

      sig { override.overridable.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig do
        params(
          generator: RbiGenerator,
          name: T.nilable(String),
          final: T::Boolean,
          block: T.nilable(T.proc.params(x: Namespace).void)
        ).void
      end
      def initialize(generator, name = nil, final = false, &block); end

      sig { returns(T::Boolean) }
      attr_reader :final

      sig { returns(T::Array[RbiObject]) }
      attr_reader :children

      sig { returns(T::Array[RbiGenerator::Extend]) }
      def extends; end

      sig { returns(T::Array[RbiGenerator::Include]) }
      def includes; end

      sig { returns(T::Array[RbiGenerator::Constant]) }
      def constants; end

      sig { params(object: T.untyped, block: T.proc.params(x: Namespace).void).void }
      def path(object, &block); end

      sig { params(comment: T.any(String, T::Array[String])).void }
      def add_comment_to_next_child(comment); end

      sig do
        params(
          name: String,
          final: T::Boolean,
          superclass: T.nilable(String),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ClassNamespace)
      end
      def create_class(name, final: false, superclass: nil, abstract: false, &block); end

      sig do
        params(
          name: String,
          final: T::Boolean,
          enums: T.nilable(T::Array[T.any([String, String], String)]),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: EnumClassNamespace).void)
        ).returns(EnumClassNamespace)
      end
      def create_enum_class(name, final: false, enums: nil, abstract: false, &block); end

      sig do
        params(
          name: String,
          final: T::Boolean,
          props: T.nilable(T::Array[StructProp]),
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: StructClassNamespace).void)
        ).returns(StructClassNamespace)
      end
      def create_struct_class(name, final: false, props: nil, abstract: false, &block); end

      sig do
        params(
          name: String,
          final: T::Boolean,
          interface: T::Boolean,
          block: T.nilable(T.proc.params(x: ClassNamespace).void)
        ).returns(ModuleNamespace)
      end
      def create_module(name, final: false, interface: false, &block); end

      sig do
        params(
          name: String,
          parameters: T.nilable(T::Array[Parameter]),
          return_type: T.nilable(String),
          returns: T.nilable(String),
          abstract: T::Boolean,
          implementation: T::Boolean,
          override: T::Boolean,
          overridable: T::Boolean,
          class_method: T::Boolean,
          final: T::Boolean,
          type_parameters: T.nilable(T::Array[Symbol]),
          block: T.nilable(T.proc.params(x: Method).void)
        ).returns(Method)
      end
      def create_method(name, parameters: nil, return_type: nil, returns: nil, abstract: false, implementation: false, override: false, overridable: false, class_method: false, final: false, type_parameters: nil, &block); end

      sig do
        params(
          name: String,
          kind: Symbol,
          type: String,
          class_attribute: T::Boolean,
          block: T.nilable(T.proc.params(x: Attribute).void)
        ).returns(Attribute)
      end
      def create_attribute(name, kind:, type:, class_attribute: false, &block); end

      sig do
        params(
          name: String,
          type: String,
          class_attribute: T::Boolean,
          block: T.nilable(T.proc.params(x: Attribute).void)
        ).returns(Attribute)
      end
      def create_attr_reader(name, type:, class_attribute: false, &block); end

      sig do
        params(
          name: String,
          type: String,
          class_attribute: T::Boolean,
          block: T.nilable(T.proc.params(x: Attribute).void)
        ).returns(Attribute)
      end
      def create_attr_writer(name, type:, class_attribute: false, &block); end

      sig do
        params(
          name: String,
          type: String,
          class_attribute: T::Boolean,
          block: T.nilable(T.proc.params(x: Attribute).void)
        ).returns(Attribute)
      end
      def create_attr_accessor(name, type:, class_attribute: false, &block); end

      sig { params(code: T.untyped, block: T.untyped).returns(T.untyped) }
      def create_arbitrary(code:, &block); end

      sig { params(name: String, block: T.nilable(T.proc.params(x: Extend).void)).returns(RbiGenerator::Extend) }
      def create_extend(name, &block); end

      sig { params(extendables: T::Array[String]).returns(T::Array[Extend]) }
      def create_extends(extendables); end

      sig { params(name: String, block: T.nilable(T.proc.params(x: Include).void)).returns(Include) }
      def create_include(name, &block); end

      sig { params(includables: T::Array[String]).returns(T::Array[Include]) }
      def create_includes(includables); end

      sig do
        params(
          name: String,
          value: String,
          eigen_constant: T::Boolean,
          block: T.nilable(T.proc.params(x: Constant).void)
        ).returns(Constant)
      end
      def create_constant(name, value:, eigen_constant: false, &block); end

      sig { params(name: String, type: String, block: T.nilable(T.proc.params(x: Constant).void)).returns(Constant) }
      def create_type_alias(name, type:, &block); end

      sig { override.overridable.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.overridable.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { override.overridable.returns(String) }
      def describe; end

      sig { overridable.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_body(indent_level, options); end

      sig { params(object: RbiObject).void }
      def move_next_comments(object); end
    end

    class Options
      extend T::Sig

      sig { params(break_params: Integer, tab_size: Integer, sort_namespaces: T::Boolean).void }
      def initialize(break_params:, tab_size:, sort_namespaces:); end

      sig { returns(Integer) }
      attr_reader :break_params

      sig { returns(Integer) }
      attr_reader :tab_size

      sig { returns(T::Boolean) }
      attr_reader :sort_namespaces

      sig { params(level: Integer, str: String).returns(String) }
      def indented(level, str); end
    end

    class Parameter
      extend T::Sig
      PREFIXES = T.let({
        normal: '',
        splat: '*',
        double_splat: '**',
        block: '&'
      }.freeze, T::Hash[Symbol, String])

      sig { params(name: String, type: T.nilable(String), default: T.nilable(String)).void }
      def initialize(name, type: nil, default: nil); end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { returns(String) }
      attr_reader :name

      sig { returns(String) }
      def name_without_kind; end

      sig { returns(String) }
      attr_reader :type

      sig { returns(T.nilable(String)) }
      attr_reader :default

      sig { returns(Symbol) }
      attr_reader :kind

      sig { returns(String) }
      def to_def_param; end

      sig { returns(String) }
      def to_sig_param; end
    end

    class RbiObject
      abstract!

      extend T::Helpers
      extend T::Sig

      sig { params(generator: RbiGenerator, name: String).void }
      def initialize(generator, name); end

      sig { returns(RbiGenerator) }
      attr_reader :generator

      sig { returns(T.nilable(Plugin)) }
      attr_reader :generated_by

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[String]) }
      attr_reader :comments

      sig { params(comment: T.any(String, T::Array[String])).void }
      def add_comment(comment); end

      sig { abstract.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_rbi(indent_level, options); end

      sig { abstract.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { abstract.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end

      sig { abstract.returns(String) }
      def describe; end

      sig { params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_comments(indent_level, options); end
    end

    class StructClassNamespace < ClassNamespace
      extend T::Sig

      sig do
        params(
          generator: RbiGenerator,
          name: String,
          final: T::Boolean,
          props: T::Array[StructProp],
          abstract: T::Boolean,
          block: T.nilable(T.proc.params(x: StructClassNamespace).void)
        ).void
      end
      def initialize(generator, name, final, props, abstract, &block); end

      sig { returns(T::Array[StructProp]) }
      attr_reader :props

      sig { override.params(indent_level: Integer, options: Options).returns(T::Array[String]) }
      def generate_body(indent_level, options); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).returns(T::Boolean) }
      def mergeable?(others); end

      sig { override.params(others: T::Array[RbiGenerator::RbiObject]).void }
      def merge_into_self(others); end
    end

    class StructProp
      extend T::Sig
      EXTRA_PROPERTIES = T.let(%i{
        optional enum dont_store foreign default factory immutable array override redaction
      }, T::Array[Symbol])

      sig do
        params(
          name: String,
          type: String,
          optional: T.nilable(T.any(T::Boolean, Symbol)),
          enum: T.nilable(String),
          dont_store: T.nilable(T::Boolean),
          foreign: T.nilable(String),
          default: T.nilable(String),
          factory: T.nilable(String),
          immutable: T.nilable(T::Boolean),
          array: T.nilable(String),
          override: T.nilable(T::Boolean),
          redaction: T.nilable(String)
        ).void
      end
      def initialize(name, type, optional: nil, enum: nil, dont_store: nil, foreign: nil, default: nil, factory: nil, immutable: nil, array: nil, override: nil, redaction: nil); end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other); end

      sig { returns(String) }
      attr_reader :name

      sig { returns(T.nilable(String)) }
      attr_reader :type

      sig { returns(T.nilable(T.any(T::Boolean, Symbol))) }
      attr_reader :optional

      sig { returns(T.nilable(String)) }
      attr_reader :enum

      sig { returns(T.nilable(T::Boolean)) }
      attr_reader :dont_store

      sig { returns(T.nilable(String)) }
      attr_reader :foreign

      sig { returns(T.nilable(String)) }
      attr_reader :default

      sig { returns(T.nilable(String)) }
      attr_reader :factory

      sig { returns(T.nilable(T::Boolean)) }
      attr_reader :immutable

      sig { returns(T.nilable(String)) }
      attr_reader :array

      sig { returns(T.nilable(T::Boolean)) }
      attr_reader :override

      sig { returns(T.nilable(String)) }
      attr_reader :redaction

      sig { returns(String) }
      def to_prop_call; end
    end
  end
end
