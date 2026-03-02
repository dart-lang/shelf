/// A rule for validating a route parameter.
abstract class RouteRule {
  const RouteRule();

  /// Validates the given [value].
  /// Returns null if valid, or an error message if invalid.
  String? validate(String? value);
}

/// A rule that ensures a parameter is present and not empty.
class Required extends RouteRule {
  const Required();

  @override
  String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'is required';
    }
    return null;
  }
}

/// A rule that ensures a parameter is a valid number.
class Number extends RouteRule {
  const Number();

  @override
  String? validate(String? value) {
    if (value == null || value.isEmpty)
      return null; // Use Required() for presence
    if (num.tryParse(value) == null) {
      return 'must be a number';
    }
    return null;
  }
}

/// A rule that ensures a parameter matches a specific regular expression.
class Regex extends RouteRule {
  final RegExp pattern;
  const Regex(this.pattern);

  @override
  String? validate(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!pattern.hasMatch(value)) {
      return 'is invalid';
    }
    return null;
  }
}
