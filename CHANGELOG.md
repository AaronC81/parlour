# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.5.0] - 2019-07-20
### Added
- Added the `create_arbitrary` method for inserting arbitrary code into the
generated RBI file. This is intended for using constructs which Parlour does
not yet support.

### Changed
- Breaking change: `add_constant`, `add_include` and `add_extend` have been
replaced with `create_constant`, `create_include` and `create_extend`.

## [0.4.0] - 2019-07-10
### Changed
- Breaking change: The Parlour CLI tool no longer takes command-line arguments, and instead uses a `.parlour` configuration file. See the README!
- RBIs now begin with `# typed: strong`.
- Plugins now define a stub constructor to avoid an exception if they don't define one.

## [0.3.1] - 2019-07-09
### Changed
- Multi-line parameter lists no longer have a trailing comma.

## [0.3.0] - 2019-07-09
### Changed
- Breaking change: all `Namespace#create_` methods, and the `Parameter` constructor, now take entirely keyword arguments.
  For example, `create_method('A', [], 'String')` is now written as `create_method(name: 'A', returns: 'String')`.

## [0.2.2] - 2019-07-08
### Fixed
- Fixed a bug which occasionally caused includes and extends to generate incorrectly.

## [0.2.1] - 2019-07-08
### Added
- Added the `add_comment_to_next_child` method to namespaces.

## [0.2.0] - 2019-07-07
### Added
- Add support for plugins using the `parlour` command-line tool.
- Comments can now be added using `add_comment`.
- Attribute readers, writers and accessors can now be created, using the `create_attr_...` methods.
- All objects are now YARD documented.

### Changed
- The `RbiObject`, which is core to Parlour's internals, is now an abstract class rather than an interface.
- `ConflictResolver` now recurses to child namespaces.
- `create_method` now takes an initializer block like other `create_` methods.

## [0.1.1] - 2019-07-05
### Added
- Initial release!

_(0.1.0 was a blank gem.)_