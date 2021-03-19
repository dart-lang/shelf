// @dart=2.12

/// Annotation for an API end-point.
class EndPoint {
  /// HTTP verb for requests routed to the annotated method.
  final String verb;

  /// HTTP route for request routed to the annotated method.
  final String route;

  /// Create an annotation that routes requests matching [verb] and [route] to
  /// the annotated method.
  const EndPoint(this.verb, this.route);

  /// Route `GET` requests matching [route] to annotated method.
  const EndPoint.get(this.route) : verb = 'GET';

  /// Route `HEAD` requests matching [route] to annotated method.
  const EndPoint.head(this.route) : verb = 'HEAD';

  /// Route `POST` requests matching [route] to annotated method.
  const EndPoint.post(this.route) : verb = 'POST';

  /// Route `PUT` requests matching [route] to annotated method.
  const EndPoint.put(this.route) : verb = 'PUT';

  /// Route `DELETE` requests matching [route] to annotated method.
  const EndPoint.delete(this.route) : verb = 'DELETE';

  /// Route `CONNECT` requests matching [route] to annotated method.
  const EndPoint.connect(this.route) : verb = 'CONNECT';

  /// Route `OPTIONS` requests matching [route] to annotated method.
  const EndPoint.options(this.route) : verb = 'OPTIONS';

  /// Route `TRACE` requests matching [route] to annotated method.
  const EndPoint.trace(this.route) : verb = 'TRACE';
}
