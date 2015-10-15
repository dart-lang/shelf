A package that provides a [shelf][] handler for serving a `packages/` directory.
It's intended to be usable as the first handler in a [`Cascade`][cascade], where
any requests that include `/packages/` are served package assets, and all other
requests cascade to additional handlers.

[shelf]: http://github.com/dart-lang/shelf
[cascade]: http://www.dartdocs.org/documentation/shelf/latest/index.html#shelf/shelf.Cascade
