import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Metrics is local and has no remote identity or projection layer', () {
    for (final file
        in Directory('lib/features/metrics')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();

      expect(
        source,
        isNot(
          matches(
            r'PocketBase|ClientException|ownerId|features/(authentication|session)/',
          ),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('infrastructure/projections/')),
        reason: file.path,
      );
    }
  });

  test('Metrics reads local expenses without importing their implementation or writing them', () {
    for (final file
        in Directory('lib/features/metrics/infrastructure')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();

      expect(
        source,
        isNot(contains('features/expense/infrastructure/')),
        reason: file.path,
      );
      expect(
        source,
        isNot(
          matches(r'\.(insert|update|delete|upsert|createTables|close)\s*\('),
        ),
        reason: file.path,
      );
    }
  });

  test(
    'Metrics keeps its shared repository bind without routes or page Blocs',
    () {
      final module = File('lib/features/metrics/metrics_module.dart')
          .readAsStringSync();

      expect(module, isNot(contains('path:')));
      expect(
        module,
        contains('addLazySingleton<IMetricsRepository>(MetricsRepository.new)'),
      );
      expect(module, isNot(contains('Bloc')));
    },
  );
}
