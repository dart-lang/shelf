import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../params.dart';

/// Middleware that validates route parameters against [rules].
///
/// If validation fails, it returns a 400 Bad Request response with a JSON
/// body containing the errors.
Middleware validate(Map<String, RouteRule> rules) {
  return (Handler innerHandler) {
    return (Request request) async {
      final params =
          (request.context['shelf_router/params'] as Map<String, String>?) ??
              {};
      final errors = <String, String>{};

      for (final entry in rules.entries) {
        final paramName = entry.key;
        final rule = entry.value;
        final value = params[paramName];

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
  };
}
