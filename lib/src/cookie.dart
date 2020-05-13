class Cookie {
  String name;
  String value;

  // TODO: Add other cookie attributes

  @override
  String toString() {
    return 'Set-Cookie: $name:$value';
  }
}
