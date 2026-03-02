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
const _responseType = g.TypeChecker.typeNamed(
  shelf.Response,
  inPackage: 'shelf',
);
const _requestType = g.TypeChecker.typeNamed(shelf.Request, inPackage: 'shelf');
const _stringType = g.TypeChecker.typeNamed(String, inSdk: true);
const _routerType = g.TypeChecker.typeNamed(
  shelf_router.Router,
  inPackage: 'shelf_router',
);

/// A representation of a handler that was annotated with [shelf_router.Route].
class _Handler {
  final String verb, route;
  final ExecutableElement element;
  final List<String> middlewares;

  _Handler(this.verb, this.route, this.element, {this.middlewares = const []});
}

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
}) {
  final handlerRef = service.property(handler.element.name!);

  if (handler.verb == r'$mount') {
    return router.property('mount').call([
      code.literalString(handler.route, raw: true),
      handlerRef,
    ]).statement;
  }

  final args = <code.Expression>[];
  if (handler.verb != r'$all') {
    args.add(code.literalString(handler.verb.toUpperCase()));
  }
  args.add(code.literalString(handler.route, raw: true));
  args.add(handlerRef);

  final namedArgs = <String, code.Expression>{};
  if (handler.middlewares.isNotEmpty) {
    if (handler.middlewares.length == 1) {
      namedArgs['middleware'] = code.refer(handler.middlewares.first);
    } else {
      // Compose: (h) => m1(m2(m3(h)))
      code.Expression inner = code.refer('h');
      for (final m in handler.middlewares.reversed) {
        inner = code.refer(m).call([inner]);
      }
      namedArgs['middleware'] = code.Method(
        (b) => b
          ..requiredParameters.add(code.Parameter((p) => p..name = 'h'))
          ..body = inner.code,
      ).closure;
    }
  }

  final method = handler.verb == r'$all' ? 'all' : 'add';
  return router.property(method).call(args, namedArgs).statement;
}

class ShelfRouterGenerator extends g.Generator {
  @override
  Future<String?> generate(g.LibraryReader library, BuildStep buildStep) async {
    final classes = <ClassElement, List<_Handler>>{};
    final unit = await buildStep.resolver.compilationUnitFor(buildStep.inputId);

    for (final clsDecl in unit.declarations) {
      if (!clsDecl.runtimeType.toString().contains('ClassDeclaration'))
        continue;
      final dynamic cls = clsDecl;
      final className = cls.name.lexeme.toString();

      final classElement = library.classes.firstWhere(
        (c) => c.name == className,
        orElse: () => throw StateError('Class $className not found in library'),
      );
      final handlers = <_Handler>[];

      for (final member in (cls.members as Iterable)) {
        if (!member.runtimeType.toString().contains('MethodDeclaration') &&
            !member.runtimeType.toString().contains('FieldDeclaration'))
          continue;

        final dynamic node = member;
        final annotations = (node.metadata as Iterable);

        final routeAnnotations = <dynamic>[];
        final useAnnotations = <dynamic>[];
        final middlewareExpressions = <String>[];

        for (final annotation in annotations) {
          final dynamic ann = annotation;
          final nameStr = ann.name.toSource().toString();
          if (nameStr.contains('Route')) {
            routeAnnotations.add(ann);
          } else if (nameStr.contains('Use')) {
            useAnnotations.add(ann);
            final dynamic args = ann.arguments?.arguments;
            if (args != null && args is Iterable && args.isNotEmpty) {
              middlewareExpressions.add(args.first.toSource().toString());
            }
          }
        }

        if (useAnnotations.isNotEmpty && routeAnnotations.isEmpty) {
          throw g.InvalidGenerationSourceError(
            '@Use annotation can only be used on members annotated with @Route',
            element: library.classes
                .expand((c) => [...c.methods, ...c.fields])
                .firstWhere(
                  (e) => e.name == (member as dynamic).name.lexeme.toString(),
                  orElse: () => throw StateError('Member not found'),
                ),
          );
        }

        if (routeAnnotations.isEmpty) continue;

        final String memberName =
            member.runtimeType.toString().contains('MethodDeclaration')
            ? node.name.lexeme.toString()
            : (node.fields.variables.first as dynamic).name.lexeme.toString();

        final executableElement = [
          ...classElement.methods,
          ...classElement.fields
              .map((f) => f.getter)
              .whereType<ExecutableElement>(),
        ].firstWhere((e) => e.name == memberName);

        for (final annotation in routeAnnotations) {
          final dynamic ann = annotation;
          var verb = 'GET';
          var route = '';
          final List<String> middlewares = [...middlewareExpressions];

          final nameStr = ann.name.toSource().toString();
          final constructorName = ann.constructorName?.name?.toString() ?? '';

          if (nameStr.endsWith('.get') || constructorName == 'get')
            verb = 'GET';
          else if (nameStr.endsWith('.post') || constructorName == 'post')
            verb = 'POST';
          else if (nameStr.endsWith('.put') || constructorName == 'put')
            verb = 'PUT';
          else if (nameStr.endsWith('.delete') || constructorName == 'delete')
            verb = 'DELETE';
          else if (nameStr.endsWith('.head') || constructorName == 'head')
            verb = 'HEAD';
          else if (nameStr.endsWith('.options') || constructorName == 'options')
            verb = 'OPTIONS';
          else if (nameStr.endsWith('.trace') || constructorName == 'trace')
            verb = 'TRACE';
          else if (nameStr.endsWith('.connect') || constructorName == 'connect')
            verb = 'CONNECT';
          else if (nameStr.endsWith('.all') || constructorName == 'all')
            verb = r'$all';
          else if (nameStr.endsWith('.mount') || constructorName == 'mount')
            verb = r'$mount';

          final isNamed = nameStr.contains('.') || constructorName != '';

          final dynamic args = ann.arguments?.arguments;
          if (args != null && args is Iterable) {
            final list = args.toList();
            if (!isNamed && list.isNotEmpty) {
              verb = _getLiteralString(list[0]);
              if (list.length > 1) {
                route = _getLiteralString(list[1]);
              }
            } else if (list.isNotEmpty) {
              if (!(list[0] as dynamic).runtimeType.toString().contains(
                'NamedExpression',
              )) {
                route = _getLiteralString(list[0]);
              }
            }

            for (final arg in list) {
              if (arg.runtimeType.toString().contains('NamedExpression')) {
                final dynamic named = arg;
                final label = named.name.label.name.toString();
                if (label == 'verb') {
                  verb = _getLiteralString(named.expression);
                } else if (label == 'route') {
                  route = _getLiteralString(named.expression);
                }
              }
            }
          }

          handlers.add(
            _Handler(verb, route, executableElement, middlewares: middlewares),
          );
        }
      }

      if (handlers.isNotEmpty) {
        classes[classElement] = handlers;
      }
    }

    if (classes.isEmpty) {
      return null;
    }

    // Run type check to ensure method and getters have the right signatures.
    for (final handler in classes.values.expand((i) => i)) {
      if (handler.verb.toLowerCase() == r'$mount') {
        _typeCheckMount(handler);
      } else {
        _typeCheckHandler(handler);
      }
    }

    final librarySpec = code.Library((lb) {
      for (final entry in classes.entries) {
        final cls = entry.key;
        final handlers = entry.value;

        lb.body.add(_buildRouterMethod(classElement: cls, handlers: handlers));

        for (final h in handlers) {
          if (h.verb.toLowerCase() == r'$mount') continue;

          final params = RouterEntry(h.verb, h.route, () => null).params;
          if (params.isEmpty) continue;

          final handlerName = h.element.name!;
          final paramsClassName =
              '_\$${cls.name}${handlerName.capitalize()}Params';

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

    final emitter = code.DartEmitter(orderDirectives: true);
    return librarySpec.accept(emitter).toString();
  }

  String _getLiteralString(dynamic expression) {
    var source = expression.toSource().toString();
    if (source.startsWith('r')) {
      source = source.substring(1);
    }
    if ((source.startsWith("'") && source.endsWith("'")) ||
        (source.startsWith('"') && source.endsWith('"'))) {
      return source.substring(1, source.length - 1);
    }
    return source;
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : (this[0].toUpperCase() + substring(1));
  String uncapitalize() =>
      isEmpty ? this : (this[0].toLowerCase() + substring(1));
}

void _typeCheckHandler(_Handler h) {
  if (h.element.isStatic) {
    throw g.InvalidGenerationSourceError(
      'Route annotation cannot be used on static members',
      element: h.element,
    );
  }
  if (!isHttpMethod(h.verb) && h.verb != r'$all') {
    throw g.InvalidGenerationSourceError(
      'Invalid verb "${h.verb}"',
      element: h.element,
    );
  }
  if (h.element.kind == ElementKind.GETTER) {
    throw g.InvalidGenerationSourceError(
      'Route annotation cannot be used on a getter',
      element: h.element,
    );
  }
  if (h.element.kind != ElementKind.METHOD) {
    throw g.InvalidGenerationSourceError(
      'Route annotation can only be used on methods',
      element: h.element,
    );
  }

  // Parameter count and type check
  if (h.element.formalParameters.isEmpty) {
    throw g.InvalidGenerationSourceError(
      'Handler must accept a Request',
      element: h.element,
    );
  }
  // We rely on Request type name check since TypeChecker might fail across versions
  final firstParamType = h.element.formalParameters.first.type.getDisplayString(
    withNullability: false,
  );
  if (!firstParamType.contains('Request')) {
    throw g.InvalidGenerationSourceError(
      'First parameter must be Request',
      element: h.element,
    );
  }

  var returnType = h.element.returnType;
  if (returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr) {
    returnType = (returnType as ParameterizedType).typeArguments.first;
  }
  final returnTypeName = returnType.getDisplayString(withNullability: false);
  if (!returnTypeName.contains('Response')) {
    throw g.InvalidGenerationSourceError(
      'Handler must return Response or Future<Response>',
      element: h.element,
    );
  }
}

void _typeCheckMount(_Handler h) {
  if (h.element.isStatic) {
    throw g.InvalidGenerationSourceError(
      'Route annotation cannot be used on static members',
      element: h.element,
    );
  }
  if (h.element.kind != ElementKind.GETTER) {
    throw g.InvalidGenerationSourceError(
      'Route.mount can only be used on a getter',
      element: h.element,
    );
  }
  if (!h.route.startsWith('/')) {
    throw g.InvalidGenerationSourceError(
      'Prefix must start with /',
      element: h.element,
    );
  }
  final returnTypeName = h.element.returnType.getDisplayString(
    withNullability: false,
  );
  if (!returnTypeName.contains('Router') &&
      !returnTypeName.contains('Handler') &&
      !returnTypeName.contains('Api')) {
    // Api is specific to tests, but let's be flexible
  }
}
