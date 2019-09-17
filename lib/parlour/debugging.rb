# typed: true
require 'rainbow'

module Parlour
  # Contains methods to enable debugging facilities for Parlour.
  module Debugging
    extend T::Sig

    @debug_mode = !ENV["PARLOUR_DEBUG"].nil?

    # Set whether debug messages should be printed.
    # @param [Boolean] value True if debug messages will be printed, false
    #   otherwise.
    # @return [Boolean] The new value.
    sig { params(value: T::Boolean).returns(T::Boolean) }
    def self.debug_mode=(value)
      @debug_mode = value
    end

    # Whether debug messages sent by {#debug_puts} should be printed.
    # Defaults to true if the PARLOUR_DEBUG environment variable is set.
    # @return [Boolean] True if debug messages will be printed, false otherwise.
    sig { returns(T::Boolean) }
    def self.debug_mode?
      @debug_mode
    end

    # Prints a message with a debugging prefix to STDOUT if {#debug_mode?} is
    # true.
    # @params [Object] object The object which is printing this debug message. 
    #   Callers should pass +self+.
    # @params [String] message The message to print. It should not contain
    #   newlines.
    # @return [void]
    sig { params(object: T.untyped, message: String).void }
    def self.debug_puts(object, message)
      return unless debug_mode?
      name = Rainbow("#{name_for_debug_caller(object)}: ").magenta.bright.bold
      prefix = Rainbow("Parlour debug: ").blue.bright.bold
      puts prefix + name + message
    end

    # Converts the given object into a human-readable prefix to a debug message.
    # For example, passing an instance of {ConflictResolver} returns
    # "conflict resolver". If the object type is unknown, this returns its class
    # name.
    # @param [Object] object The object to convert.
    # @return [String] A string describing the object for {#debug_puts}. 
    sig { params(object: T.untyped).returns(String) }
    def self.name_for_debug_caller(object)
      case object
      when ConflictResolver
        "conflict resolver"
      when RbiGenerator
        "RBI generator"
      else
        if ((object < Plugin) rescue false)
          return "plugin #{object.name}"
        end
        object.class.name
      end
    end

    # A module for generating a globally-consistent, nicely-formatted tree of
    # output using Unicode block characters.
    module Tree
      extend T::Sig

      # The number of spaces to indent each layer of the tree by. Should be at
      # least 1.
      INDENT_SPACES = 2

      # The current indent level of the tree.
      @indent_level = 0

      # Returns a new heading, and then decents the tree one level into it. 
      # (That is, future output will go under the new heading.)
      # @param [String] message The heading.
      # @return [String] The line of this tree which should be printed.
      sig { params(message: String).returns(String) }
      def self.begin(message)
        result = line_prefix + '├' + text_prefix + Rainbow(message).green.bright.bold
        @indent_level += 1
        result
      end

      # Prints a new tree element at the current level.
      # @param [String] message The element.
      # @return [String] The line of this tree which should be printed.
      sig { params(message: String).returns(String) }
      def self.here(message)
        line_prefix + '├' + text_prefix + message
      end

      # Prints the final tree element at the current level, then ascends one
      # level.
      # @param [String] message The element.
      # @return [String] The line of this tree which should be printed.
      sig { params(message: String).returns(String) }
      def self.end(message)
        result = line_prefix + '└' + text_prefix + message
        @indent_level = [0, @indent_level - 1].max
        result
      end

      # The prefix which should be printed before anything else on this line of
      # the tree, based on the current indent level.
      # @return [String]
      def self.line_prefix
        @indent_level.times.map { '│' + ' ' * INDENT_SPACES }.join
      end

      # The horizontal lines which should be printed between the beginning of
      # the current element and its text, based on the specified number of
      # spaces to use for indents.
      # @return [String]
      def self.text_prefix
        '─' * (INDENT_SPACES - 1) + " "
      end
    end
  end
end