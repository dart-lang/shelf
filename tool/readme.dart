import 'dart:io';

const _pkgsDir = 'pkgs';

void main() {
  final dirs = Directory(_pkgsDir).listSync().whereType<Directory>();
  final pkgs = dirs.map(Package.new).toList()..sort();

  print('Package | Description | Version');
  print('--- | --- | ---');
  for (var pkg in pkgs) {
    _printPkg(pkg);
  }
}

void _printPkg(Package pkg) {
  print(
    '[${pkg.name}](${pkg.path}/) | ${pkg.description} | '
    '[![pub package](https://img.shields.io/pub/v/${pkg.name}.svg)](https://pub.dev/packages/${pkg.name})',
  );
}

class Package implements Comparable<Package> {
  final Directory dir;

  Package(this.dir);

  String get name => dir.path.substring(dir.path.lastIndexOf('/') + 1);
  String get path => dir.path;
  String get description {
    // An quick and dirty yaml parser (this script doesn't currently have access
    // to package:pubspec).
    var pubspec = File('${dir.path}/pubspec.yaml');
    var contents = pubspec.readAsStringSync().replaceAll('>\n', '');
    return contents
        .split('\n')
        .firstWhere((line) => line.startsWith('description:'))
        .substring('description:'.length)
        .trim();
  }

  @override
  int compareTo(Package other) => name.compareTo(other.name);
}
