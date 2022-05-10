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

/// This library provides a [Builder] for generating functions that can create
/// a [shelf_router.Router] based on annotated members.
///
/// This is **not intended** for consumption, this library should be used by
/// running `pub run build_runner build`. Using this library through other means
/// is not supported and may break arbitrarily.
library builder;

import 'package:build/build.dart';
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:source_gen/source_gen.dart';

import 'src/shelf_router_generator.dart';

/// A [Builder] that generates a `_$<className>Router(<className> service)`
/// function for each class `<className>` containing a member annotated with
/// [shelf_router.Route].
Builder shelfRouter(BuilderOptions _) => SharedPartBuilder(
      [ShelfRouterGenerator()],
      'shelf_router',
    );
