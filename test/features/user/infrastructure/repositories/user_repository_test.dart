import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';

import '../../../../support/user/fakes/profile_query_interceptor.dart';

void main() {
  group('Perfil SQLite', () {
    late DatabaseClient database;
    late ProfileQueryInterceptor interceptor;
    late UserRepository repository;

    setUp(() {
      interceptor = ProfileQueryInterceptor();
      database = DatabaseClient(
        executor: NativeDatabase.memory().interceptWith(interceptor),
      );
      repository = UserRepository(database: database);
    });

    tearDown(() => database.close());

    test(
      'cria e persiste ID, nome padrão e seed aleatória na primeira leitura',
      () async {
        final profile = await repository.get();
        final stored = await database
            .select(database.profilesTable)
            .getSingle();

        expect(profile.id, greaterThan(0));
        expect(profile.name, 'Cordato');
        expect(profile.seed, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(stored.id, profile.id);
        expect(stored.name, profile.name);
        expect(stored.seed, profile.seed);
        expect(interceptor.insertions, 1);
      },
    );

    test('leituras seguintes preservam o perfil sem novas escritas', () async {
      final original = await repository.get();

      final reloaded = await UserRepository(database: database).get();

      expect(reloaded.id, original.id);
      expect(reloaded.name, original.name);
      expect(reloaded.seed, original.seed);
      expect(interceptor.insertions, 1);
      expect(interceptor.updates, 0);
    });

    test('consultas concorrentes inicializam exatamente um perfil', () async {
      final profiles = await Future.wait(
        List.generate(10, (_) => UserRepository(database: database).get()),
      );

      expect(profiles.map((profile) => profile.id).toSet(), hasLength(1));
      expect(profiles.map((profile) => profile.seed).toSet(), hasLength(1));
      expect(await database.select(database.profilesTable).get(), hasLength(1));
      expect(interceptor.insertions, 1);
    });

    test('atualizar antes de consultar cria e edita o perfil', () async {
      final updated = await repository.update(
        name: 'Gabriel',
        seed: 'chosen-seed',
      );
      final saved = await repository.get();

      expect(saved.id, updated.id);
      expect(saved.name, 'Gabriel');
      expect(saved.seed, 'chosen-seed');
      expect(interceptor.insertions, 1);
      expect(interceptor.updates, 1);
    });

    test('alterar nome preserva ID e seed sem normalizar', () async {
      final original = await repository.get();

      final updated = await repository.update(name: '  Gabriel  ');

      expect(updated.id, original.id);
      expect(updated.name, '  Gabriel  ');
      expect(updated.seed, original.seed);
    });

    test('alterar seed preserva ID e nome sem normalizar', () async {
      final original = await repository.get();

      final updated = await repository.update(seed: '  chosen-seed  ');

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.seed, '  chosen-seed  ');
    });

    test('preserva seed vazia ao atualizar somente nome', () async {
      await repository.update(seed: '');

      final updated = await repository.update(name: 'Gabriel');

      expect(updated.seed, isEmpty);
    });

    test('update vazio apenas lê sem gravar', () async {
      final original = await repository.get();

      final unchanged = await repository.update();

      expect(unchanged.id, original.id);
      expect(unchanged.name, original.name);
      expect(unchanged.seed, original.seed);
      expect(interceptor.updates, 0);
    });

    test(
      'updates concorrentes de campos distintos preservam as duas alterações',
      () async {
        final original = await repository.get();

        await Future.wait([
          repository.update(name: 'Gabriel'),
          UserRepository(database: database).update(seed: 'chosen-seed'),
        ]);
        final saved = await repository.get();

        expect(saved.id, original.id);
        expect(saved.name, 'Gabriel');
        expect(saved.seed, 'chosen-seed');
      },
    );

    test('não mantém cache de alterações externas', () async {
      final original = await repository.get();
      await database
          .update(database.profilesTable)
          .write(
            const ProfilesTableCompanion(
              name: Value('External'),
              seed: Value('external-seed'),
            ),
          );

      final saved = await repository.get();

      expect(saved.id, original.id);
      expect(saved.name, 'External');
      expect(saved.seed, 'external-seed');
    });

    group('Falhas', () {
      for (final code in [
        SqlError.SQLITE_BUSY,
        SqlError.SQLITE_LOCKED,
        SqlError.SQLITE_READONLY,
        SqlError.SQLITE_IOERR,
        SqlError.SQLITE_FULL,
        SqlError.SQLITE_CANTOPEN,
        SqlExtendedError.SQLITE_IOERR_READ,
      ]) {
        test(
          'converte falha operacional SQLite $code sem expor diagnóstico',
          () async {
            interceptor.beforeRead = () async => throw SqliteException(
              extendedResultCode: code,
              message: 'private diagnostic',
            );

            await expectLater(repository.get(), throwsA(isA<UserException>()));
            await expectLater(
              repository.update(name: 'Gabriel'),
              throwsA(isA<UserException>()),
            );
            expect(interceptor.insertions, 0);
            expect(interceptor.updates, 0);
          },
        );
      }

      test(
        'converte falha de filesystem na inicialização sem sucesso falso',
        () async {
          interceptor.beforeInsert = () async =>
              throw const FileSystemException('private path');

          await expectLater(repository.get(), throwsA(isA<UserException>()));

          expect(await database.select(database.profilesTable).get(), isEmpty);
        },
      );

      test('falha no update preserva dados e permite retry manual', () async {
        final original = await repository.get();
        interceptor.beforeUpdate = () async => throw SqliteException(
          extendedResultCode: SqlError.SQLITE_FULL,
          message: 'private path',
        );

        await expectLater(
          repository.update(name: 'Gabriel'),
          throwsA(isA<UserException>()),
        );
        final unchanged = await repository.get();
        expect(unchanged.id, original.id);
        expect(unchanged.name, original.name);
        expect(unchanged.seed, original.seed);

        interceptor.beforeUpdate = null;
        final updated = await repository.update(name: 'Gabriel');
        expect(updated.id, original.id);
        expect(updated.name, 'Gabriel');
      });

      test(
        'falha ao atualizar perfil ausente também reverte sua criação',
        () async {
          interceptor.beforeUpdate = () async =>
              throw const FileSystemException('private path');

          await expectLater(
            repository.update(name: 'Gabriel'),
            throwsA(isA<UserException>()),
          );

          expect(await database.select(database.profilesTable).get(), isEmpty);
        },
      );

      test('falha no commit não é retornada como sucesso', () async {
        interceptor.beforeCommit = () async => throw SqliteException(
          extendedResultCode: SqlError.SQLITE_IOERR,
          message: 'private diagnostic',
        );

        await expectLater(repository.get(), throwsA(isA<UserException>()));

        expect(await database.select(database.profilesTable).get(), isEmpty);
      });

      for (final failure in [
        StateError('unexpected'),
        const FormatException('invalid data'),
        TypeError(),
        SqliteException(
          extendedResultCode: SqlError.SQLITE_CONSTRAINT,
          message: 'constraint',
        ),
        SqliteException(
          extendedResultCode: SqlError.SQLITE_ERROR,
          message: 'SQL error',
        ),
        SqliteException(
          extendedResultCode: SqlError.SQLITE_CORRUPT,
          message: 'corrupt',
        ),
      ]) {
        test('propaga falha inesperada $failure sem gravar defaults', () async {
          interceptor.beforeRead = () async => throw failure;

          await expectLater(repository.get(), throwsA(same(failure)));
          await expectLater(
            repository.update(name: 'Gabriel'),
            throwsA(same(failure)),
          );
          expect(interceptor.insertions, 0);
          expect(interceptor.updates, 0);
        });
      }

      test(
        'propaga falha inesperada de escrita e reverte a transação',
        () async {
          final failure = StateError('unexpected write');
          interceptor.beforeInsert = () async => throw failure;

          await expectLater(repository.get(), throwsA(same(failure)));

          expect(await database.select(database.profilesTable).get(), isEmpty);
        },
      );
    });

    group('Conclusão das operações', () {
      test(
        'get aguarda a escrita e commit antes de publicar o perfil',
        () async {
          final started = Completer<void>();
          final pending = Completer<void>();
          interceptor.beforeCommit = () {
            started.complete();
            return pending.future;
          };
          bool completed = false;
          final reading = repository.get().then((profile) {
            completed = true;
            return profile;
          });

          try {
            await started.future;
            expect(completed, isFalse);
          } finally {
            pending.complete();
          }

          expect((await reading).name, 'Cordato');
          expect(completed, isTrue);
        },
      );

      test(
        'update aguarda a escrita antes de retornar os novos dados',
        () async {
          await repository.get();
          final started = Completer<void>();
          final pending = Completer<void>();
          interceptor.beforeUpdate = () {
            started.complete();
            return pending.future;
          };
          bool completed = false;
          final updating = repository.update(name: 'Gabriel').then((profile) {
            completed = true;
            return profile;
          });

          try {
            await started.future;
            expect(completed, isFalse);
          } finally {
            pending.complete();
          }

          expect((await updating).name, 'Gabriel');
          expect(completed, isTrue);
        },
      );
    });
  });

  group('Falhas pelo isolate', () {
    Future<DatabaseClient> openBackgroundDatabase() async {
      final directory = await Directory.systemTemp.createTemp(
        'cordato-user-errors-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = DatabaseClient(
        executor: NativeDatabase.createInBackground(
          File('${directory.path}/cordato.sqlite'),
        ),
      );
      addTearDown(database.close);
      return database;
    }

    test(
      'converte erro readonly remoto e preserva perfil para retry',
      () async {
        final database = await openBackgroundDatabase();
        final repository = UserRepository(database: database);
        final original = await repository.get();
        await database.customStatement('PRAGMA query_only = ON');

        await expectLater(
          repository.update(name: 'Gabriel'),
          throwsA(isA<UserException>()),
        );

        await database.customStatement('PRAGMA query_only = OFF');
        final unchanged = await repository.get();
        expect(unchanged.id, original.id);
        expect(unchanged.name, original.name);
        expect(unchanged.seed, original.seed);

        final updated = await repository.update(name: 'Gabriel');
        expect(updated.id, original.id);
        expect(updated.name, 'Gabriel');
      },
    );

    test('propaga erro SQL remoto sem recriar schema ou perfil', () async {
      final database = await openBackgroundDatabase();
      final repository = UserRepository(database: database);
      await repository.get();
      await database.customStatement('DROP TABLE profiles');

      await expectLater(
        repository.get(),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.resultCode,
            'resultCode',
            SqlError.SQLITE_ERROR,
          ),
        ),
      );

      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'profiles'",
          )
          .get();
      expect(tables, isEmpty);
    });
  });

  test(
    'preserva ID, nome e seed após fechar e reabrir arquivo em isolate',
    () async {
      final directory = await Directory.systemTemp.createTemp('cordato-user-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/cordato.sqlite');
      final first = DatabaseClient(
        executor: NativeDatabase.createInBackground(file),
      );
      late int savedId;

      try {
        final profile = await UserRepository(database: first)
            .update(name: 'Gabriel', seed: 'chosen-seed');
        savedId = profile.id;
      } finally {
        await first.close();
      }

      final reopened = DatabaseClient(
        executor: NativeDatabase.createInBackground(file),
      );
      try {
        final profile = await UserRepository(database: reopened).get();

        expect(profile.id, savedId);
        expect(profile.name, 'Gabriel');
        expect(profile.seed, 'chosen-seed');
      } finally {
        await reopened.close();
      }
    },
  );
}
