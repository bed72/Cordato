import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

void main() {
  group('SQLite em memória', () {
    late DatabaseClient database;

    setUp(() {
      database = DatabaseClient(
        executor: NativeDatabase.memory(
          setup: DatabaseClient.configureConnection,
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    Future<int> insertProfile() async {
      return database
          .into(database.profilesTable)
          .insert(
            ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed-1'),
          );
    }

    Future<int> insertExpense({
      int? id,
      int profileId = 1,
      int amount = 1250,
      String occurredOn = '2026-11-23',
    }) async {
      return database
          .into(database.expensesTable)
          .insert(
            ExpensesTableCompanion.insert(
              id: id == null ? const Value.absent() : Value(id),
              profileId: profileId,
              amount: amount,
              occurredOn: Value(occurredOn),
            ),
          );
    }

    group('Schema inicial', () {
      test('default SQL preenche data civil local ao omitir a coluna', () async {
        await insertProfile();
        final before = DateTime.now();

        final inserted = await database
            .into(database.expensesTable)
            .insertReturning(
              ExpensesTableCompanion.insert(profileId: 1, amount: 100),
            );
        final after = DateTime.now();

        String civilDate(DateTime date) =>
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        expect(inserted.occurredOn, anyOf(civilDate(before), civilDate(after)));
        final columns = await database
            .customSelect('PRAGMA table_info(expenses)')
            .get();
        expect(
          columns
              .singleWhere(
                (column) => column.read<String>('name') == 'occurred_on',
              )
              .read<String>('dflt_value'),
          "date('now', 'localtime')",
        );
      });

      test('localtime respeita componentes locais junto à virada do dia UTC', () async {
        final sample = DateTime.utc(2026, 11, 23, 1, 30).toLocal();
        final row = await database
            .customSelect(
              "SELECT date('2026-11-23 01:30:00', 'localtime') AS civil",
            )
            .getSingle();
        final expected =
            '${sample.year.toString().padLeft(4, '0')}-${sample.month.toString().padLeft(2, '0')}-${sample.day.toString().padLeft(2, '0')}';

        expect(row.read<String>('civil'), expected);
      });

      test(
        'registra lowercase Unicode sem remover acentos ou normalizar texto',
        () async {
          final row = await database
              .customSelect(
                "SELECT cordato_lower('CAFÉ AÇÃO Σ') AS folded, cordato_lower(NULL) AS missing",
              )
              .getSingle();

          expect(row.read<String>('folded'), 'CAFÉ AÇÃO Σ'.toLowerCase());
          expect(row.data['missing'], isNull);
        },
      );

      test('cria versão 1 vazia com foreign keys habilitadas', () async {
        final profiles = await database.select(database.profilesTable).get();
        final expenses = await database.select(database.expensesTable).get();
        final foreignKeys = await database
            .customSelect('PRAGMA foreign_keys')
            .getSingle();
        final version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(profiles, isEmpty);
        expect(expenses, isEmpty);
        expect(foreignKeys.read<int>('foreign_keys'), 1);
        expect(version.read<int>('user_version'), 1);
      });

      test('permite somente um perfil mesmo com IDs diferentes', () async {
        await insertProfile();

        await expectLater(insertProfile(), throwsA(isA<SqliteException>()));

        final profiles = await database.select(database.profilesTable).get();
        expect(profiles.single.id, 1);
      });

      test(
        'gera IDs inteiros nas duas tabelas sem fornecer IDs no insert',
        () async {
          final profileId = await insertProfile();
          final firstExpenseId = await insertExpense(profileId: profileId);
          final secondExpenseId = await insertExpense(profileId: profileId);

          final profile = await database
              .select(database.profilesTable)
              .getSingle();
          final expenses = await database.select(database.expensesTable).get();

          expect(profileId, greaterThan(0));
          expect(profile.id, profileId);
          expect(secondExpenseId, greaterThan(firstExpenseId));
          expect(
            expenses.map((expense) => expense.id),
            unorderedEquals([firstExpenseId, secondExpenseId]),
          );
          expect(expenses.map((expense) => expense.profileId).toSet(), {
            profileId,
          });
        },
      );

      test(
        'não reutiliza IDs após exclusão de despesas e cascade do perfil',
        () async {
          final originalProfileId = await insertProfile();
          final originalExpenseId = await insertExpense(
            profileId: originalProfileId,
          );
          await database.delete(database.expensesTable).go();
          final nextExpenseId = await insertExpense(
            profileId: originalProfileId,
          );

          await database.delete(database.profilesTable).go();
          final nextProfileId = await insertProfile();
          final newestExpenseId = await insertExpense(profileId: nextProfileId);

          expect(nextExpenseId, greaterThan(originalExpenseId));
          expect(nextProfileId, greaterThan(originalProfileId));
          expect(newestExpenseId, greaterThan(nextExpenseId));
        },
      );

      test('preserva ID e despesas ao editar nome e seed', () async {
        await insertProfile();
        await insertExpense();

        await database
            .update(database.profilesTable)
            .write(
              const ProfilesTableCompanion(
                name: Value('Gabriel'),
                seed: Value('seed-2'),
              ),
            );

        final profile = await database
            .select(database.profilesTable)
            .getSingle();
        final expense = await database
            .select(database.expensesTable)
            .getSingle();
        expect(profile.id, 1);
        expect(profile.name, 'Gabriel');
        expect(profile.seed, 'seed-2');
        expect(expense.profileId, profile.id);
      });

      test(
        'mantém centavos inteiros, categoria padrão e descrição nula',
        () async {
          await insertProfile();
          await insertExpense(amount: 9007199254740993);

          final expense = await database
              .select(database.expensesTable)
              .getSingle();

          expect(expense.amount, 9007199254740993);
          expect(expense.category, 'other');
          expect(expense.description, isNull);
          expect(expense.occurredOn, '2026-11-23');
        },
      );
    });

    group('Integridade', () {
      test('rejeita despesa sem perfil existente', () async {
        await expectLater(insertExpense(), throwsA(isA<SqliteException>()));
      });

      for (final amount in [0, -1]) {
        test('rejeita valor de $amount centavos', () async {
          await insertProfile();

          await expectLater(
            insertExpense(amount: amount),
            throwsA(isA<SqliteException>()),
          );
        });
      }

      test('rejeita centavos fracionários mesmo por SQL direto', () async {
        await insertProfile();

        await expectLater(
          database.customStatement(
            "INSERT INTO expenses (profile_id, amount, occurred_on) "
            "VALUES (1, 1.5, '2026-11-23')",
          ),
          throwsA(isA<SqliteException>()),
        );
      });

      for (final date in [
        '2026-02-29',
        '2026-04-31',
        '2026-13-01',
        '2026-11-23T00:00:00Z',
        'invalid',
        '0000-01-01',
      ]) {
        test('rejeita data civil inválida: $date', () async {
          await insertProfile();

          await expectLater(
            insertExpense(occurredOn: date),
            throwsA(isA<SqliteException>()),
          );
        });
      }

      test('aceita dia bissexto sem conversão de fuso', () async {
        await insertProfile();
        await insertExpense(occurredOn: '2024-02-29');

        final expense = await database
            .select(database.expensesTable)
            .getSingle();

        expect(expense.occurredOn, '2024-02-29');
      });

      test('rejeita ID textual do perfil por SQL direto', () async {
        await expectLater(
          database.customStatement(
            "INSERT INTO profiles (id, name, seed) VALUES ('', 'Cordato', 'seed')",
          ),
          throwsA(isA<SqliteException>()),
        );
      });

      test('rejeita ID duplicado de despesa', () async {
        await insertProfile();
        await insertExpense();

        await expectLater(
          insertExpense(id: 1),
          throwsA(isA<SqliteException>()),
        );
      });

      for (final field in ['profile_id', 'amount', 'occurred_on']) {
        test('rejeita $field nulo por SQL direto', () async {
          await insertProfile();

          await expectLater(
            database.customStatement(
              'INSERT INTO expenses (profile_id, amount, occurred_on) '
              'VALUES (?, ?, ?)',
              [
                field == 'profile_id' ? null : 1,
                field == 'amount' ? null : 100,
                field == 'occurred_on' ? null : '2026-11-23',
              ],
            ),
            throwsA(isA<SqliteException>()),
          );
        });
      }

      test('rejeita ID textual da despesa por SQL direto', () async {
        await insertProfile();

        await expectLater(
          database.customStatement(
            "INSERT INTO expenses (id, profile_id, amount, occurred_on) "
            "VALUES ('invalid-id', 1, 100, '2026-11-23')",
          ),
          throwsA(isA<SqliteException>()),
        );
      });

      test('rejeita categoria vazia por SQL direto', () async {
        await insertProfile();

        await expectLater(
          database.customStatement(
            "INSERT INTO expenses (profile_id, amount, category, occurred_on) "
            "VALUES (1, 100, '', '2026-11-23')",
          ),
          throwsA(isA<SqliteException>()),
        );
      });

      for (final category in [
        'unknown',
        'FOOD',
        ' food',
        'food ',
        'personalCare',
        "food') OR 1=1 --",
      ]) {
        test(
          'rejeita categoria inválida em insert e update: $category',
          () async {
            await insertProfile();
            await insertExpense();

            await expectLater(
              database.customStatement(
                'INSERT INTO expenses (profile_id, amount, category) VALUES (1, 100, ?)',
                [category],
              ),
              throwsA(isA<SqliteException>()),
            );
            await expectLater(
              database.customStatement('UPDATE expenses SET category = ?', [
                category,
              ]),
              throwsA(isA<SqliteException>()),
            );

            final expense = await database
                .select(database.expensesTable)
                .getSingle();
            expect(expense.category, 'other');
          },
        );
      }

      test('rejeita categoria nula por SQL direto', () async {
        await insertProfile();

        await expectLater(
          database.customStatement(
            'INSERT INTO expenses (profile_id, amount, category) VALUES (1, 100, NULL)',
          ),
          throwsA(isA<SqliteException>()),
        );
      });
    });

    group('Cascade e transações', () {
      test('apagar uma despesa preserva o perfil', () async {
        await insertProfile();
        await insertExpense();

        await database.delete(database.expensesTable).go();

        final profile = await database
            .select(database.profilesTable)
            .getSingle();
        expect(profile.id, 1);
        expect(await database.select(database.expensesTable).get(), isEmpty);
      });
      test('apaga todas as despesas quando remove o perfil', () async {
        await insertProfile();
        await insertExpense();
        await insertExpense();

        await database.delete(database.profilesTable).go();

        expect(await database.select(database.profilesTable).get(), isEmpty);
        expect(await database.select(database.expensesTable).get(), isEmpty);
      });

      test(
        'permite substituir perfil e rejeita escritas do perfil antigo',
        () async {
          await insertProfile();
          await insertExpense();

          await database.transaction(() async {
            await database.delete(database.profilesTable).go();
            await insertProfile();
          });

          await expectLater(insertExpense(), throwsA(isA<SqliteException>()));

          final profile = await database
              .select(database.profilesTable)
              .getSingle();
          expect(profile.id, 2);
          expect(await database.select(database.expensesTable).get(), isEmpty);
        },
      );

      test('reverte perfil e cascade se a substituição falhar', () async {
        await insertProfile();
        await insertExpense();

        await expectLater(
          database.transaction(() async {
            await database.delete(database.profilesTable).go();
            await insertProfile();
            await insertProfile();
          }),
          throwsA(isA<SqliteException>()),
        );

        final profile = await database
            .select(database.profilesTable)
            .getSingle();
        final expense = await database
            .select(database.expensesTable)
            .getSingle();
        expect(profile.id, 1);
        expect(expense.profileId, profile.id);
      });
    });
  });

  group('Persistência em arquivo', () {
    test(
      'reabre versão 1 preservando dados, CHECK, índice único e cascade',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cordato-drift-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/cordato.sqlite');
        final initial = DatabaseClient(
          executor: NativeDatabase.createInBackground(
            file,
            setup: DatabaseClient.configureConnection,
          ),
        );

        try {
          final profileId = await initial
              .into(initial.profilesTable)
              .insert(
                ProfilesTableCompanion.insert(
                  name: 'Cordato',
                  seed: 'saved-seed',
                ),
              );
          await initial
              .into(initial.expensesTable)
              .insert(
                ExpensesTableCompanion.insert(
                  profileId: profileId,
                  amount: 123,
                  occurredOn: const Value('2026-11-23'),
                ),
              );
        } finally {
          await initial.close();
        }

        final reopened = DatabaseClient(
          executor: NativeDatabase.createInBackground(
            file,
            setup: DatabaseClient.configureConnection,
          ),
        );

        try {
          final profile = await reopened
              .select(reopened.profilesTable)
              .getSingle();
          final expense = await reopened
              .select(reopened.expensesTable)
              .getSingle();
          expect(profile.seed, 'saved-seed');
          final folded = await reopened
              .customSelect("SELECT cordato_lower('CAFÉ') AS value")
              .getSingle();
          expect(folded.read<String>('value'), 'café');
          expect(expense.amount, 123);
          expect(expense.profileId, profile.id);
          final version = await reopened
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), 1);
          await expectLater(
            reopened.customStatement(
              "UPDATE expenses SET category = 'unknown'",
            ),
            throwsA(
              isA<DriftRemoteException>().having(
                (error) => error.remoteCause,
                'remoteCause',
                isA<SqliteException>(),
              ),
            ),
          );
          expect(
            (await reopened.select(reopened.expensesTable).getSingle())
                .category,
            'other',
          );

          await expectLater(
            reopened
                .into(reopened.profilesTable)
                .insert(
                  ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'),
                ),
            throwsA(
              isA<DriftRemoteException>().having(
                (error) => error.remoteCause,
                'remoteCause',
                isA<SqliteException>(),
              ),
            ),
          );

          await reopened.delete(reopened.profilesTable).go();
          expect(await reopened.select(reopened.expensesTable).get(), isEmpty);

          final newProfileId = await reopened
              .into(reopened.profilesTable)
              .insert(
                ProfilesTableCompanion.insert(
                  name: 'Cordato',
                  seed: 'new-seed',
                ),
              );
          final newExpenseId = await reopened
              .into(reopened.expensesTable)
              .insert(
                ExpensesTableCompanion.insert(
                  profileId: newProfileId,
                  amount: 100,
                  occurredOn: const Value('2026-11-23'),
                ),
              );

          expect(newProfileId, greaterThan(profile.id));
          expect(newExpenseId, greaterThan(expense.id));
        } finally {
          await reopened.close();
        }
      },
    );
  });
}
