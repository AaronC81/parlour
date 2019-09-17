# typed: strong
require 'sorbet-runtime'

require 'parlour/version'

require 'parlour/debugging'

require 'parlour/kernel_hack'

require 'parlour/plugin'

require 'parlour/rbi_generator/parameter'
require 'parlour/rbi_generator/rbi_object'
require 'parlour/rbi_generator/method'
require 'parlour/rbi_generator/attribute'
require 'parlour/rbi_generator/arbitrary'
require 'parlour/rbi_generator/options'
require 'parlour/rbi_generator/include'
require 'parlour/rbi_generator/extend'
require 'parlour/rbi_generator/constant'
require 'parlour/rbi_generator/namespace'
require 'parlour/rbi_generator/module_namespace'
require 'parlour/rbi_generator/class_namespace'
require 'parlour/rbi_generator'

require 'parlour/conflict_resolver'
