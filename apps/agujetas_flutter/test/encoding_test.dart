import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project text files stay valid UTF-8 without mojibake', () {
    final root = Directory.current;
    final files =
        _auditedRoots(root)
            .expand((entity) {
              if (entity is File) return [entity];
              if (entity is Directory) {
                return entity
                    .listSync(recursive: true, followLinks: false)
                    .whereType<File>();
              }
              return const <File>[];
            })
            .where(_shouldAuditTextFile)
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final failures = <String>[];
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      late final String content;
      try {
        content = utf8.decode(bytes, allowMalformed: false);
      } on FormatException catch (error) {
        failures.add('${file.path}: UTF-8 inválido ($error)');
        continue;
      }

      for (final marker in _mojibakeMarkers) {
        if (content.contains(marker)) {
          failures.add('${file.path}: contiene marcador mojibake "$marker"');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

List<FileSystemEntity> _auditedRoots(Directory root) {
  final candidates = [
    Directory('${root.path}/lib'),
    Directory('${root.path}/test'),
    Directory('${root.path}/docs'),
    Directory('${root.path}/android/app/src/main'),
    Directory('${root.path}/ios/Runner'),
    File('${root.path}/pubspec.yaml'),
    File('${root.path}/analysis_options.yaml'),
    File('${root.path}/README.md'),
  ];
  return candidates.where((entity) => entity.existsSync()).toList();
}

bool _shouldAuditTextFile(File file) {
  final normalized = file.path.replaceAll('\\', '/');
  return _textExtensions.any(normalized.endsWith);
}

const _textExtensions = [
  '.dart',
  '.md',
  '.json',
  '.yaml',
  '.yml',
  '.html',
  '.xml',
  '.gradle',
  '.properties',
  '.plist',
];

final _mojibakeMarkers = [
  String.fromCharCode(0x00c3),
  String.fromCharCode(0x00c2),
  String.fromCharCodes([0x00e2, 0x20ac]),
  String.fromCharCodes([0x00e2, 0x20ac, 0x2122]),
  String.fromCharCodes([0x00e2, 0x20ac, 0x0153]),
  String.fromCharCodes([0x00e2, 0x20ac, 0xfffd]),
  String.fromCharCodes([0x00f0, 0x0178]),
  String.fromCharCode(0xfffd),
];
