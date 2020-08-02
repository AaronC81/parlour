# typed: true
module Parlour
  module Conversion
    # Converts RBI types to RBS types.
    class RbiToRbs < Converter
      extend T::Sig

      sig { params(rbi: RbiGenerator::RbiObject, rbs_gen: RbsGenerator).void }
      def initialize(rbi, rbs_gen)
        super()
        @rbi = rbi
        @rbs_gen = rbs_gen
      end

      sig { returns(RbiGenerator::RbiObject) }
      attr_reader :rbi

      sig { returns(RbsGenerator) }
      attr_reader :rbs_gen

      sig do
        params(
          node: RbiGenerator::RbiObject,
          new_parent: RbsGenerator::Namespace,
        ).void
      end
      def convert_object(node, new_parent)        
        case node
        when RbiGenerator::Arbitrary
          add_warning 'converting type of Arbitrary is likely to cause syntax errors', node

        when RbiGenerator::Attribute
          if node.class_attribute
            add_warning 'RBS does not support class attributes; dropping', node
            return
          end
          new_parent.create_attribute(
            node.name,
            kind: node.kind,
            type: node.type,
          ).add_comments(node.comments)

        when RbiGenerator::ClassNamespace
          if node.abstract
            add_warning 'RBS does not support abstract classes', node
          end
          klass = new_parent.create_class(
            node.name,
            superclass: node.superclass
          )
          klass.add_comments(node.comments)
          node.children.each do |child|
            convert_object(child, klass)
          end

        when RbiGenerator::Constant
          if node.eigen_constant
            add_warning 'RBS does not support constants on eigenclasses; dropping', node
            return
          end
          new_parent.create_constant(
            node.name,
            type: node.value,
          ).add_comments(node.comments)

        when RbiGenerator::EnumClassNamespace
          add_warning 'RBS does not support enums; dropping', node
          return

        when RbiGenerator::Extend
          new_parent.create_extend(node.name).add_comments(node.comments)

        when RbiGenerator::Include
          new_parent.create_include(node.name).add_comments(node.comments)

        when RbiGenerator::Method
          # Convert parameters
          parameters = node.parameters
            .reject { |param| param.kind == :block }
            .map do |param|
              RbsGenerator::Parameter.new(
                param.name,
                type: param.type,
                required: param.default.nil?
              )
            end

          # Find block if there is one
          block_param = node.parameters.find { |param| param.kind == :block }
          if block_param
            if String === block_param.type
              add_warning "block must have a Types::Type for conversion; dropping block", node
              block = nil
            else
              # A nilable proc is an optional block
              block_param_type = block_param.type
              if Types::Nilable === block_param_type && Types::Proc === block_param_type.type
                t = T.cast(block_param_type.type, Types::Proc)
                required = false
                RbsGenerator::Block.new(t, required)
              elsif Types::Proc === block_param_type
                t = block_param_type
                required = true
                RbsGenerator::Block.new(t, required)
              elsif Types::Untyped === block_param_type
                # Consider there to be no block
                block = nil
              else
                add_warning 'block type must be a Types::Proc (or nilable one); dropping block', node
              end
            end
          else
            block = nil
          end

          new_parent.create_method(
            node.name,
            [
              RbsGenerator::MethodSignature.new(
                parameters,
                node.return_type,
                block: block,
                type_parameters: node.type_parameters,
              )
            ],
            class_method: node.class_method,
          ).add_comments(node.comments)

        when RbiGenerator::ModuleNamespace
          if node.interface
            add_warning 'interfaces not yet implemented', node
          end
          mod = new_parent.create_module(
            node.name,
          )
          mod.add_comments(node.comments)
          node.children.each do |child|
            convert_object(child, mod)
          end

        when RbiGenerator::Namespace
          add_warning 'unspecialized namespaces are not supposed to be in the tree; you may run into issues', node
          namespace = RbsGenerator::Namespace.new(rbs_gen)
          namespace.add_comments(node.comments)
          node.children.each do |child|
            convert_object(child, namespace)
          end
          new_parent.children << namespace

        when RbiGenerator::StructClassNamespace
          add_warning 'RBS does not support structs; dropping', node
          return

        else
          raise "missing conversion for #{rbi.describe}"
          # TODO: stick a T.absurd here
        end
      end
    end
  end
end