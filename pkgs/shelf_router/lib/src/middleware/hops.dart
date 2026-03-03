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

import 'package:shelf/shelf.dart';

/// Middleware that logs the number of trie nodes (hops) traversed during
/// route matching.
///
/// This middleware looks for the 'shelf_router.hops' key in the
/// response context.
///
/// An optional [logger] can be provided to handle the log message
/// (defaults to [print]).
Middleware logHops([void Function(String) logger = print]) =>
    (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        final hops = response.context['shelf_router.hops'];
        if (hops is int) {
          logger('Request to ${request.url.path} took $hops trie hops');
        }
        return response;
      };
    };
