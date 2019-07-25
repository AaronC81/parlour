# Parlour

[![Build Status](https://travis-ci.org/AaronC81/parlour.svg?branch=master)](https://travis-ci.org/AaronC81/parlour)
![Gem](https://img.shields.io/gem/v/parlour.svg)

Parlour is an RBI generator and merger for Sorbet. It consists of two key parts:

  - The generator, which outputs beautifully formatted RBI files, created using
    an intuitive DSL.

  - The plugin/build system, which allows multiple Parlour plugins to generate
    RBIs for the same codebase. These are combined automatically as much as 
    possible, but any other conflicts can be resolved manually through prompts.

## Why should I use this?

  - Parlour enables **much easier creation of RBI generators**, as formatting
    is all handled for you, and you don't need to write your own CLI.

  - You can **use many plugins together seamlessly**, running them all with a
    single command and consolidating all of their definitions into a single
    RBI output file.


Please [**read the wiki**](https://github.com/AaronC81/parlour/wiki) to get
started!

## Creating RBIs

### Using just the generator

Here's a quick example of how you can generate an RBI:

```ruby
require 'parlour'

generator = Parlour::RbiGenerator.new
generator.root.create_module('A') do |a|
  a.create_class('Foo') do |foo|
    foo.create_method('add_two_integers', parameters: [
      Parlour::RbiGenerator::Parameter.new('a', type: 'Integer'),
      Parlour::RbiGenerator::Parameter.new('b', type: 'Integer')
    ], return_type: 'Integer')
  end

  a.create_class('Bar', superclass: 'Foo')
end

generator.rbi # => Our RBI as a string
```

This will generate the following RBI:

```ruby
module A
  class Foo
    sig { params(a: Integer, b: Integer).returns(Integer) }
    def add_two_integers(a, b); end
  end

  class Bar < Foo
  end
end
```

### Writing a plugin
Plugins are better than using the generator alone, as your plugin can be 
combined with others to produce larger RBIs without conflicts.

We could write the above example as a plugin like this:

```ruby
require 'parlour'

class MyPlugin < Parlour::Plugin
  def generate(root)
    root.create_module('A') do |a|
      a.create_class('Foo') do |foo|
        foo.create_method('add_two_integers', parameters: [
          Parlour::RbiGenerator::Parameter.new('a', type: 'Integer'),
          Parlour::RbiGenerator::Parameter.new('b', type: 'Integer')
        ], return_type: 'Integer')
      end

      a.create_class('Bar', superclass: 'Foo')
    end
  end
end
```

(Obviously, your plugin will probably examine a codebase somehow, to be more
useful!)

You can then run several plugins, combining their output and saving it into one
RBI file, using the command-line tool. The command line tool is configurated
using a `.parlour` YAML file. For example, if that code was in a file
called `plugin.rb`, then using this `.parlour` file and then running `parlour`
would save the RBI into `output.rbi`:

```yaml
output_file: output.rbi

relative_requires:
  - plugin.rb
  
plugins:
  MyPlugin: {}
```

The `{}` indicates that this plugin needs no extra configuration. If it did need
configuration, this could be specified like so:

```yaml
plugins:
  MyPlugin:
    foo: something
    bar: something else
```

You can also use plugins from gems. If that plugin was published as a gem called
`parlour-gem`:

```yaml
output_file: output.rbi

requires:
  - parlour-gem
  
plugins:
  MyPlugin: {}
```

The real power of this is the ability to use many plugins at once:

```yaml
output_file: output.rbi

requires:
  - gem1
  - gem2
  - gem3
  
plugins:
  Gem1::Plugin: {}
  Gem2::Plugin: {}
  Gem3::Plugin: {}
```

## Parlour Plugins

_Have you written an awesome Parlour plugin? Please submit a PR to add it to this list!_

  - [Sord](https://github.com/AaronC81/sord) - Generate RBIs from YARD documentation
  - [parlour-datamapper](https://github.com/AaronC81/parlour-datamapper) - Simple plugin for generating DataMapper model types


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/AaronC81/parlour. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Parlour project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/AaronC81/parlour/blob/master/CODE_OF_CONDUCT.md).
