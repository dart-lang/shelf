## v0.8.0-nullsafety.0

 * Migrate package to null-safety
 * Since handlers are not allowed to return `null` in `shelf` 1.0.0, a router
   will return a default 404 response instead.
   This behavior can be overridden with the `notFoundHandler` constructor
   parameter.

## v0.7.4

 * Update `Router.mount` parameter to accept a `Handler`.
 * Make `Router` to be considered a `Handler`.
 * Deprecate the `Router.handler` getter.

## v0.7.3

 * Added `@sealed` annotation to `Router` and `Route`.

## v0.7.2

 * Always register a `HEAD` handler whenever a `GET` handler is registered.
   Defaulting to calling the `GET` handler and throwing away the body.

## v0.7.1

 * Use `Function` instead of `dynamic` in `RouterEntry` to improve typing.

## v0.7.0+1

 * Fixed description to fit size recommendations.

## v0.7.0

 * Initial release
