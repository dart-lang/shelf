// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class ComplianceResult {
  final Map<String, dynamic> _json;

  ComplianceResult(this._json);

  factory ComplianceResult.fromJson(Map<String, dynamic> json) {
    return ComplianceResult(json);
  }

  String get id => _json['id'] as String;
  String? get description => _json['description'] as String?;
  String? get category => _json['category'] as String?;
  ResultVerdict get verdict =>
      ResultVerdict.values.byName(_json['verdict'] as String);

  Map<String, dynamic> toJson() => _json;
}

// ignore: constant_identifier_names
enum ResultVerdict { Pass, Fail, Warn, Skip, Error }
