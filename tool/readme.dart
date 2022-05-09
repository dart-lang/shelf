import 'dart:io';

const _pkgsDir = 'pkgs';

void main() {
  final dirs = Directory(_pkgsDir).listSync().whereType<Directory>();

  final pkgs = dirs.map((e) => e.uri.pathSegments[1]).toList()..sort();

  for (var pkg in pkgs) {
    _printPkg(pkg);
  }
}

void _printPkg(String pkgName) {
  print('''
## $pkgName [![Pub Package](https://img.shields.io/pub/v/$pkgName.svg)](https://pub.dev/packages/$pkgName)

- Package: <https://pub.dev/packages/$pkgName>
- [Source code]($_pkgsDir/$pkgName)
''');
}
