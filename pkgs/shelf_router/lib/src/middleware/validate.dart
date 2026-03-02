import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../params.dart';

/// Middleware that validates route parameters against [rules].
///
/// If validation fails, it returns a 400 Bad Request response with a JSON
/// body containing the errors.
/// Middleware that validates route parameters against [rules].
///
/// If validation fails, it returns a 400 Bad Request response with a JSON
/// body containing the errors.
class validateParams {
  final Map<String, RouteRule> rules;
  const validateParams(this.rules);

  Handler call(Handler innerHandler) {
    return (Request request) async {
      final pathParams =
          (request.context['shelf_router/params'] as Map<String, String>?) ??
              {};
      final queryParams = request.url.queryParameters;
      final errors = <String, String>{};

      for (final entry in rules.entries) {
        final paramName = entry.key;
        final rule = entry.value;

        // Path parameters are always required.
        // Query parameters are optional and only validated if present.
        final isPathParam = pathParams.containsKey(paramName);
        final value = pathParams[paramName] ?? queryParams[paramName];

        if (isPathParam) {
          if (value == null || value.isEmpty) {
            errors[paramName] = 'is required';
            continue;
          }
        }

        final error = rule.validate(value);
        if (error != null) {
          errors[paramName] = error;
        }
      }

      if (errors.isNotEmpty) {
        return Response(
          400,
          body: jsonEncode({'error': 'Validation failed', 'details': errors}),
          headers: {'content-type': 'application/json'},
        );
      }

      return innerHandler(request);
    };
  }
}
