import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release CI uses the minimum Flutter version required by the app', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final workflow = File('.github/workflows/android-release.yml')
        .readAsStringSync();
    final minimumFlutter = RegExp(r"flutter: '>=([0-9.]+)'")
        .firstMatch(pubspec)!
        .group(1)!;

    expect(workflow, contains("flutter-version: '$minimumFlutter'"));
    expect(pubspec, contains('sdk: ^3.14.0'));
  });

  test('app uses standalone design packages and their localizations', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final legacyImports = RegExp(
      r'''package:(?:flutter/(?:material|cupertino)\.dart|flutter_localizations/)''',
    );

    expect(pubspec, isNot(contains('  flutter_localizations:')));

    for (final file in dartFiles) {
      expect(
        legacyImports.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }

    for (final path in [
      'lib/features/root/presentation/widgets/app_widget.dart',
      'lib/features/core/presentation/previews/material_preview_widget.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('GlobalMaterialLocalizations.delegates'),
        reason: path,
      );
    }
  });
}
