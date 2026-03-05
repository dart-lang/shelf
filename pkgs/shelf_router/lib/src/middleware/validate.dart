// Copyright 2026 Google LLC
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

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../params.dart';
import 'annotate_middleware.dart';

/// Middleware that validates route parameters against [rules].
///
/// If validation fails, it returns a 400 Bad Request response with a JSON
/// body containing the errors.
/// Middleware that validates route parameters against [rules].
///
/// If validation fails, it returns a 400 Bad Request response with a JSON
/// body containing the errors.
class ValidateParams extends AnnotateMiddleware {
  final Map<String, RouteRule> rules;

  const ValidateParams(this.rules);

  @override
  Middleware get middleware => (Handler innerHandler) {
    return (Request request) async {
      // Retrieve path parameters from the request context.
      final pathParams =
          (request.context['shelf_router/params'] as Map<String, String>?) ??
          {};
      final queryParams = request.url.queryParameters;
      final errors = <String, String>{};

      for (final entry in rules.entries) {
        final paramName = entry.key;
        final rule = entry.value;

        final isPathParam = pathParams.containsKey(paramName);
        final value = pathParams[paramName] ?? queryParams[paramName];

        if (isPathParam) {
          if (value == null || value.isEmpty) {
            errors[paramName] = 'is required';
            continue;
          }
        }

        // Validate value against the RouteRule.
        final error = rule.validate(value);
        if (error != null) {
          errors[paramName] = error;
        }
      }

      if (errors.isNotEmpty) {
        // Return a 400 Bad Request if validation fails.
        return Response(
          400,
          body: jsonEncode({'error': 'Validation failed', 'details': errors}),
          headers: {'content-type': 'application/json'},
        );
      }

      return await innerHandler(request);
    };
  };
}
