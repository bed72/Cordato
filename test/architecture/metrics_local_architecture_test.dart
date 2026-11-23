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

  test('Metrics keeps SQL and Drift inside infrastructure without schema objects', () {
    final dao = File(
      'lib/features/metrics/infrastructure/daos/metrics_dao.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/metrics/infrastructure/repositories/metrics_repository.dart',
    ).readAsStringSync();
    final database = File(
      'lib/features/core/infrastructure/clients/database/database_client.dart',
    ).readAsStringSync();

    expect(dao, contains('extends DatabaseAccessor<DatabaseClient>'));
    expect(dao, contains('SUM(amount)'));
    expect(dao, contains('GROUP BY category'));
    expect(dao, contains('profile_id = (SELECT id FROM profiles)'));
    expect(repository, contains('required final MetricsDao _dao'));
    expect(repository, isNot(contains('Localstore')));
    expect(repository, isNot(contains('customSelect')));
    expect(database, isNot(contains('features/metrics/')));
    expect(database, isNot(contains('MetricsDao')));
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
      expect(module, contains('addLazySingleton<MetricsDao>(MetricsDao.new)'));
      expect(module, isNot(contains('Bloc')));
    },
  );
}
