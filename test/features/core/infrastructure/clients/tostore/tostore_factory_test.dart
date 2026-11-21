import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';

void main() {
  late Directory directory;
  late ToStore database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-tostore-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: const [],
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('awaited opening delivers a writable persistent database', () async {
    final savedSetting = await database.setValue('setting', 'saved');

    expect(savedSetting.hasErrors, isFalse);
    expect(await database.getValue('setting'), 'saved');
  });

  test('uses durable recovery with journal and persistent storage', () {
    expect(
      database.config.defaultRecoveryDurability,
      RecoveryDurability.durable,
    );
    expect(database.config.enableJournal, isTrue);
    expect(database.config.persistenceMode, PersistenceMode.file);
  });

  test('closing and reopening retains acknowledged writes', () async {
    final savedSetting = await database.setValue('setting', 'saved');
    expect(savedSetting.hasErrors, isFalse);

    await database.close();
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: const [],
    );

    expect(await database.getValue('setting'), 'saved');
  });

  test('opening a path beneath a file fails without deleting it', () async {
    final obstruction = File('${directory.path}/obstruction');
    await obstruction.writeAsString('preserve');

    await expectLater(
      ToStoreFactory.create(
        directory: '${obstruction.path}/database',
        schemas: const [],
      ),
      throwsA(isA<Exception>()),
    );

    expect(await obstruction.readAsString(), 'preserve');
  });
}
