## v1.1.1

 * Fix `Router.routeNotFound` to enable multiple `read()` calls on it.

## v1.1.0
 * `params` is deprecated in favor of `Request.params` adding using an extension
   on `Request`.
 * The default `notFoundHandler` now returns a sentinel `routeNotFound` response
   object which causes 404 with the message 'Route not found'.
 * __Minor breaking__: Handlers and sub-routers that return the sentinel
   `routeNotFound` response object will be ignored and pattern matching will
   continue on additional routes/handlers.

Changing the router to continue pattern matching additional routes if a matched
_handler_ or _nested router_ returns the sentinel `routeNotFound` response
object is technically a _breaking change_. However, it only affects scenarios
where the request matches a _mounted sub-router_, but does not match any route
on this sub-router. In this case, `shelf_router` version `1.0.0` would
immediately respond 404, without attempting to match further routes. With this
release, the behavior changes to matching additional routes until one returns
a custom 404 response object, or all routes have been matched.

This behavior is more in line with how `shelf_router` version `0.7.x` worked,
and since many affected users consider the behavior from `1.0.0` a defect,
we decided to remedy the situation.

## v1.0.0

 * Migrate package to null-safety
 * Since handlers are not allowed to return `null` in `shelf` 1.0.0, a router
   will return a default 404 response instead.
   This behavior can be overridden with the `notFoundHandler` constructor
   parameter.
 * __Breaking__: Remove deprecated `Router.handler` getter.
   The router itself is a handler.

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
