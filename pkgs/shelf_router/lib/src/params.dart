/// A rule for validating a route parameter.
abstract class RouteRule {
  const RouteRule();

  /// Validates the given [value].
  /// Returns null if valid, or an error message if invalid.
  String? validate(String? value);
}

/// Entry point for parameter validation rules.
///
/// Use the named constructors to create rules for different types.
class Rule extends RouteRule {
  final bool _isNumber;
  final num? _min;
  final num? _max;
  final String? _matches;

  const Rule._({
    bool isNumber = false,
    num? min,
    num? max,
    String? matches,
  })  : assert(min == null || min >= 0, 'min must be non-negative'),
        assert(max == null || max >= 0, 'max must be non-negative'),
        assert(min == null || max == null || min <= max,
            'min cannot be greater than max'),
        _isNumber = isNumber,
        _min = min,
        _max = max,
        _matches = matches;

  /// Create a string validation rule.
  const Rule.string({
    int? min,
    int? max,
    String? matches,
  }) : this._(
          min: min,
          max: max,
          matches: matches,
        );

  /// Create a number validation rule.
  const Rule.number({
    num? min,
    num? max,
  }) : this._(
          isNumber: true,
          min: min,
          max: max,
        );

  @override
  String? validate(String? value) {
    if (value == null || value.isEmpty) return null;

    if (_isNumber) {
      final n = num.tryParse(value);
      if (n == null) return 'must be a number';
      if (_min != null && n < _min) return 'must be at least $_min';
      if (_max != null && n > _max) return 'must be at most $_max';
    } else {
      // String validation
      if (_min != null && value.length < _min) {
        return 'must be at least ${_min.toInt()} characters';
      }
      if (_max != null && value.length > _max) {
        return 'must be at most ${_max.toInt()} characters';
      }
      if (_matches != null) {
        if (!RegExp(_matches).hasMatch(value)) return 'is invalid';
      }
    }
    return null;
  }
}
