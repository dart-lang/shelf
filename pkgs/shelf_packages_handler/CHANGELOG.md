## 3.0.3

* Reject request path segments containing encoded path separators (`%2F`, and
  `%5C` on Windows), `:` on Windows, NUL bytes, `.`, or `..` (and invalid
  package names) with `404 Not Found`, while continuing to follow symbolic links
  inside package directories (note: this also changes in-package encoded slashes
  such as `/packages/foo/dir%2Fb.dart` from `200` to `404`).
* Return `404 Not Found` instead of throwing a `StateError` for empty package
  paths, and avoid caching handlers for nonexistent packages.
* Require Dart `^3.9.0`.

## 3.0.2

* Added package topics to the pubspec file.
* Require Dart `2.17`.

## 3.0.1

* Require Dart `2.14`.
* Update the pubspec `repository` field.

## 3.0.0

* Migrate to null safety.

## 2.0.1

* Allow the latest (null-safe) version of `pkg:shelf`.

## 2.0.0

### Breaking changes

* Dropped the dependency on `package_resolver`.
    * All `PackageResolver` apis now take a `Map<String, Uri>` of package name to the base uri for resolving `package:`
      uris for that package.
    * Named arguments have been renamed from `resolver` to `packageMap`.

## 1.0.4

* Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 1.0.3

* Require Dart SDK 1.22.0
* Support `package:async` v2

## 1.0.2

* Fix Strong mode errors with `package:shelf` v0.7.x

## 1.0.1

* Allow dependencies on `package:shelf` v0.7.x

## 0.0.1

* Initial version
