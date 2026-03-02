// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// While we support the older pkg:analyzer version
// ignore_for_file: deprecated_member_use

import 'dart:async' show Future;

import 'package:analyzer/dart/element/element.dart'
    show ClassElement, ElementKind, ExecutableElement;
import 'package:analyzer/dart/element/type.dart' show ParameterizedType;
import 'package:build/build.dart' show BuildStep, log;
import 'package:code_builder/code_builder.dart' as code;
import 'package:http_methods/http_methods.dart' show isHttpMethod;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_router/src/router_entry.dart' // ignore: implementation_imports
    show RouterEntry;
import 'package:source_gen/source_gen.dart' as g;

// Type checkers that we need later
const _routeType = g.TypeChecker.typeNamed(
  shelf_router.Route,
  inPackage: 'shelf_router',
);
const _routerType = g.TypeChecker.typeNamed(
  shelf_router.Router,
  inPackage: 'shelf_router',
);
const _responseType = g.TypeChecker.typeNamed(
  shelf.Response,
  inPackage: 'shelf',
);
const _requestType = g.TypeChecker.typeNamed(shelf.Request, inPackage: 'shelf');
const _stringType = g.TypeChecker.typeNamed(String, inSdk: true);

/// A representation of a handler that was annotated with [shelf_router.Route].
class _Handler {
  final String verb, route;
  final ExecutableElement element;

  _Handler(this.verb, this.route, this.element);
}

/// Find members of a class annotated with [shelf_router.Route].
List<ExecutableElement> getAnnotatedElementsOrderBySourceOffset(
  ClassElement cls,
) =>
    <ExecutableElement>[
      ...cls.methods.where(_routeType.hasAnnotationOfExact),
      ...cls.getters.where(_routeType.hasAnnotationOfExact),
    ]..sort(
      (a, b) =>
          (a.firstFragment.nameOffset!).compareTo(b.firstFragment.nameOffset!),
    );

/// Generate a `_$<className>Router(<className> service)` method that returns a
/// [shelf_router.Router] configured based on annotated handlers.
code.Method _buildRouterMethod({
  required ClassElement classElement,
  required List<_Handler> handlers,
}) => code.Method(
  (b) => b
    ..name = '_\$${classElement.name}Router'
    ..requiredParameters.add(
      code.Parameter(
        (b) => b
          ..name = 'service'
          ..type = code.refer(classElement.name!),
      ),
    )
    ..returns = code.refer('Router')
    ..body = code.Block(
      (b) => b
        ..addExpression(
          code
              .declareFinal('router')
              .assign(code.refer('Router').newInstance([])),
        )
        ..statements.addAll(
          handlers.map(
            (h) => _buildAddHandlerCode(
              router: code.refer('router'),
              service: code.refer('service'),
              handler: h,
            ),
          ),
        )
        ..addExpression(code.refer('router').returned),
    ),
);

/// Generate the code statement that adds [handler] from [service] to [router].
code.Code _buildAddHandlerCode({
  required code.Reference router,
  required code.Reference service,
  required _Handler handler,
}) => switch (handler.verb) {
  r'$mount' => router.property('mount').call([
    code.literalString(handler.route, raw: true),
    service.property(handler.element.name!).property('call'),
  ]).statement,
  r'$all' => router.property('all').call([
    code.literalString(handler.route, raw: true),
    service.property(handler.element.name!),
  ]).statement,
  _ => router.property('add').call([
    code.literalString(handler.verb.toUpperCase()),
    code.literalString(handler.route, raw: true),
    service.property(handler.element.name!),
  ]).statement,
};

class ShelfRouterGenerator extends g.Generator {
  @override
  Future<String?> generate(g.LibraryReader library, BuildStep buildStep) async {
    // Create a map from ClassElement to list of annotated elements sorted by
    // offset in source code, this is not type checked yet.
    final classes = <ClassElement, List<_Handler>>{};
    for (final cls in library.classes) {
      final elements = getAnnotatedElementsOrderBySourceOffset(cls);
      if (elements.isEmpty) {
        continue;
      }
      log.info('found shelf_router.Route annotations in ${cls.name}');

      classes[cls] = elements
          .map(
            (e) => _routeType
                .annotationsOfExact(e)
                .map(
                  (a) => _Handler(
                    a.getField('verb')!.toStringValue()!,
                    a.getField('route')!.toStringValue()!,
                    e,
                  ),
                ),
          )
          .expand((i) => i)
          .toList();
    }
    if (classes.isEmpty) {
      return null; // nothing to do if nothing was annotated
    }

    // Run type check to ensure method and getters have the right signatures.
    for (final handler in classes.values.expand((i) => i)) {
      // If the verb is $mount, then it's not a handler, but a mount.
      if (handler.verb.toLowerCase() == r'$mount') {
        _typeCheckMount(handler);
      } else {
        _typeCheckHandler(handler);
      }
    }

    // Build library and emit code with all generate methods.
    final librarySpec = code.Library((lb) {
      for (final entry in classes.entries) {
        final cls = entry.key;
        final handlers = entry.value;

        lb.body.add(_buildRouterMethod(classElement: cls, handlers: handlers));

        // Generate Params classes and extensions for each handler
        for (final h in handlers) {
          if (h.verb.toLowerCase() == r'$mount') continue;

          final params = RouterEntry(h.verb, h.route, () => null).params;
          if (params.isEmpty) continue;

          final handlerName = h.element.name!;
          final paramsClassName =
              '_\$${cls.name}${handlerName.capitalize()}Params';

          // Generate Params class
          lb.body.add(
            code.Class(
              (cb) => cb
                ..name = paramsClassName
                ..fields.add(
                  code.Field(
                    (fb) => fb
                      ..name = '_params'
                      ..type = code.refer('Map<String, String>')
                      ..modifier = code.FieldModifier.final$,
                  ),
                )
                ..constructors.add(
                  code.Constructor(
                    (conb) => conb
                      ..requiredParameters.add(
                        code.Parameter(
                          (pb) => pb
                            ..name = '_params'
                            ..toThis = true,
                        ),
                      ),
                  ),
                )
                ..methods.addAll(
                  params.map(
                    (p) => code.Method(
                      (mb) => mb
                        ..name = p
                        ..type = code.MethodType.getter
                        ..returns = code.refer('String')
                        ..body = code
                            .refer('_params')
                            .index(code.literalString(p))
                            .nullChecked
                            .code,
                    ),
                  ),
                ),
            ),
          );

          // Generate Extension on Request
          lb.body.add(
            code.Extension(
              (eb) => eb
                ..name = '_\$${cls.name}${handlerName.capitalize()}Request'
                ..on = code.refer('Request', 'package:shelf/shelf.dart')
                ..methods.add(
                  code.Method(
                    (mb) => mb
                      ..name = '${handlerName.uncapitalize()}Params'
                      ..type = code.MethodType.getter
                      ..returns = code.refer(paramsClassName)
                      ..body = code.refer(paramsClassName).newInstance([
                        code.refer('this').property('params'),
                      ]).code,
                  ),
                ),
            ),
          );
        }
      }
    });

    return librarySpec.accept(code.DartEmitter()).toString();
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : (this[0].toUpperCase() + substring(1));
  String uncapitalize() =>
      isEmpty ? this : (this[0].toLowerCase() + substring(1));
}

/// Type checks for the case where [shelf_router.Route] is used to annotate
/// shelf request handler.
void _typeCheckHandler(_Handler h) {
  if (h.element.isStatic) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route annotation cannot be used on static members',
      element: h.element,
    );
  }

  // Check the verb, note that $all is a special value for handling all verbs.
  if (!isHttpMethod(h.verb) && h.verb != r'$all') {
    throw g.InvalidGenerationSourceError(
      'The verb "${h.verb}" used in shelf_router.Route annotation must be '
      'a valid HTTP method',
      element: h.element,
    );
  }

  // Check that this shouldn't have been annotated with Route.mount
  if (h.element.kind == ElementKind.GETTER) {
    throw g.InvalidGenerationSourceError(
      'Only the shelf_router.Route.mount annotation can only be used on a '
      'getter, and only if it returns a shelf_router.Router',
      element: h.element,
    );
  }

  // Check that this is indeed a method
  if (h.element.kind != ElementKind.METHOD) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route annotation can only be used on request '
      'handling methods',
      element: h.element,
    );
  }

  // Check the route can parse
  List<String> params;
  try {
    params = RouterEntry(h.verb, h.route, () => null).params;
    // ignore: avoid_catching_errors
  } on ArgumentError catch (e) {
    throw g.InvalidGenerationSourceError(e.toString(), element: h.element);
  }

  // Ensure that the first parameter is shelf.Request
  if (h.element.formalParameters.isEmpty) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route annotation can only be used on shelf request '
      'handlers accept a shelf.Request parameter',
      element: h.element,
    );
  }
  for (final p in h.element.formalParameters) {
    if (p.isOptional) {
      throw g.InvalidGenerationSourceError(
        'The shelf_router.Route annotation can only be used on shelf '
        'request handlers accept a shelf.Request parameter and/or a '
        'shelf.Request parameter and all string parameters in the route, '
        'optional parameters are not permitted',
        element: p,
      );
    }
  }
  if (!_requestType.isExactlyType(h.element.formalParameters.first.type)) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route annotation can only be used on shelf request '
      'handlers accept a shelf.Request parameter as first parameter',
      element: h.element,
    );
  }
  if (h.element.formalParameters.length > 1) {
    if (h.element.formalParameters.length != params.length + 1) {
      throw g.InvalidGenerationSourceError(
        'The shelf_router.Route annotation can only be used on shelf '
        'request handlers accept a shelf.Request parameter and all string '
        'parameters in the route (or just a shelf.Request parameter if using '
        'the generated Params object)',
        element: h.element,
      );
    }
    for (var i = 0; i < params.length; i++) {
      final p = h.element.formalParameters[i + 1];
      if (p.name != params[i]) {
        throw g.InvalidGenerationSourceError(
          'The shelf_router.Route annotation can only be used on shelf '
          'request handlers accept a shelf.Request parameter and/or a '
          'shelf.Request parameter and all string parameters in the route, '
          'the "${p.name}" parameter should be named "${params[i]}"',
          element: p,
        );
      }
      if (!_stringType.isExactlyType(p.type)) {
        throw g.InvalidGenerationSourceError(
          'The shelf_router.Route annotation can only be used on shelf '
          'request handlers accept a shelf.Request parameter and/or a '
          'shelf.Request parameter and all string parameters in the route, '
          'the "${p.name}" parameter is not of type string',
          element: p,
        );
      }
    }
  }

  // Check the return value of the method.
  var returnType = h.element.returnType;
  // Unpack Future<T> and FutureOr<T> wrapping of responseType
  if (returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr) {
    returnType = (returnType as ParameterizedType).typeArguments.first;
  }
  if (!_responseType.isAssignableFromType(returnType)) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route annotation can only be used on shelf request '
      'handlers that return shelf.Response, Future<shelf.Response> or '
      'FutureOr<shelf.Response>, and not "${h.element.returnType}"',
      element: h.element,
    );
  }
}

/// Type checks for the case where [shelf_router.Route.mount] is used to
/// annotate a getter that returns a [shelf_router.Router].
void _typeCheckMount(_Handler h) {
  if (h.element.isStatic) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route annotation cannot be used on static members',
      element: h.element,
    );
  }

  // Check that this should have been annotated with Route.mount
  if (h.element.kind != ElementKind.GETTER) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route.mount annotation can only be used on a '
      'getter that returns shelf_router.Router',
      element: h.element,
    );
  }

  // Sanity checks for the prefix
  if (!h.route.startsWith('/')) {
    throw g.InvalidGenerationSourceError(
      'The prefix "${h.route}" in shelf_router.Route.mount(prefix) '
      'annotation must begin with a slash',
      element: h.element,
    );
  }
  if (h.route.contains('<')) {
    throw g.InvalidGenerationSourceError(
      'The prefix "${h.route}" in shelf_router.Route.mount(prefix) '
      'annotation cannot contain <',
      element: h.element,
    );
  }

  if (!_routerType.isAssignableFromType(h.element.returnType)) {
    throw g.InvalidGenerationSourceError(
      'The shelf_router.Route.mount annotation can only be used on a '
      'getter that returns shelf_router.Router',
      element: h.element,
    );
  }
}
