[![Build Status](https://github.com/dart-lang/shelf/workflows/Dart%20CI/badge.svg)](https://github.com/dart-lang/shelf/actions?query=workflow%3A"Dart+CI"+branch%3Amaster)

## About Shelf

Shelf makes it easy to create and compose web servers and parts of web servers. How?

- Expose a small set of simple types.
- Map server logic into a simple function: a single argument for the request, the response is the return value.
- Trivially mix and match synchronous and asynchronous processing.
- Flexibility to return a simple string or a byte stream with the same model.

It was inspired by [Connect](https://github.com/senchalabs/connect) for NodeJS
and [Rack](https://github.com/rack/rack) for Ruby.

See the [package:shelf readme](pkgs/shelf/) for more information.

## Packages

| Package | Description | Issues | Version |
| --- | --- | --- | --- |
| [shelf](pkgs/shelf/) | A model for web server middleware that encourages composition and easy reuse. | [![issues](https://img.shields.io/badge/shelf-4774bc)][shelf_issues] | [![pub package](https://img.shields.io/pub/v/shelf.svg)](https://pub.dev/packages/shelf) |
| [shelf_packages_handler](pkgs/shelf_packages_handler/) | A shelf handler for serving a `packages/` directory. | [![issues](https://img.shields.io/badge/shelf__packages__handler-4774bc)][shelf_packages_handler_issues] | [![pub package](https://img.shields.io/pub/v/shelf_packages_handler.svg)](https://pub.dev/packages/shelf_packages_handler) |
| [shelf_proxy](pkgs/shelf_proxy/) | A shelf handler for proxying HTTP requests to another server. | [![issues](https://img.shields.io/badge/shelf__proxy-4774bc)][shelf_proxy_issues] | [![pub package](https://img.shields.io/pub/v/shelf_proxy.svg)](https://pub.dev/packages/shelf_proxy) |
| [shelf_router](pkgs/shelf_router/) | A convenient request router for the shelf web-framework, with support for URL-parameters, nested routers and routers generated from source annotations. | [![issues](https://img.shields.io/badge/shelf__router-4774bc)][shelf_router_issues] | [![pub package](https://img.shields.io/pub/v/shelf_router.svg)](https://pub.dev/packages/shelf_router) |
| [shelf_router_generator](pkgs/shelf_router_generator/) | A package:build-compatible builder for generating request routers for the shelf web-framework based on source annotations. | [![issues](https://img.shields.io/badge/shelf__router__generator-4774bc)][shelf_router_generator_issues] | [![pub package](https://img.shields.io/pub/v/shelf_router_generator.svg)](https://pub.dev/packages/shelf_router_generator) |
| [shelf_static](pkgs/shelf_static/) | Static file server support for the shelf package and ecosystem. | [![issues](https://img.shields.io/badge/shelf__static-4774bc)][shelf_static_issues] | [![pub package](https://img.shields.io/pub/v/shelf_static.svg)](https://pub.dev/packages/shelf_static) |
| [shelf_test_handler](pkgs/shelf_test_handler/) | A Shelf handler that makes it easy to test HTTP interactions. | [![issues](https://img.shields.io/badge/shelf__test__handler-4774bc)][shelf_test_handler_issues] | [![pub package](https://img.shields.io/pub/v/shelf_test_handler.svg)](https://pub.dev/packages/shelf_test_handler) |
| [shelf_web_socket](pkgs/shelf_web_socket/) | A shelf handler that wires up a listener for every connection. | [![issues](https://img.shields.io/badge/shelf__web__socket-4774bc)][shelf_web_socket_issues] | [![pub package](https://img.shields.io/pub/v/shelf_web_socket.svg)](https://pub.dev/packages/shelf_web_socket) |

[shelf_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf
[shelf_packages_handler_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_packages_handler
[shelf_proxy_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_proxy
[shelf_router_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_router
[shelf_router_generator_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_router_generator
[shelf_static_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_static
[shelf_test_handler_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_test_handler
[shelf_web_socket_issues]: https://github.com/dart-lang/shelf/issues?q=is%3Aissue+is%3Aopen+label%3Apackage%3Ashelf_web_socket

## Publishing automation

For information about our publishing automation and release process, see
https://github.com/dart-lang/ecosystem/wiki/Publishing-automation.
