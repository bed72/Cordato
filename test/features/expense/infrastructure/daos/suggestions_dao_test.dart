import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/expense/infrastructure/daos/suggestions_dao.dart';

import '../../../../support/expense/fakes/expense_query_interceptor.dart';

void main() {
  late DatabaseClient database;
  late SuggestionsDao dao;
  late ExpenseQueryInterceptor interceptor;
  late int profileId;

  setUp(() async {
    interceptor = ExpenseQueryInterceptor();
    database = DatabaseClient(
      executor: NativeDatabase.memory(setup: DatabaseClient.configureConnection)
          .interceptWith(interceptor),
    );
    dao = SuggestionsDao(client: database);
    profileId = await database
        .into(database.profilesTable)
        .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
  });

  tearDown(() => database.close());

  Future<int> insert({
    String? description = 'Mercado',
    String date = '2026-11-23',
    int amount = 100,
    String category = 'other',
  }) => database
      .into(database.expensesTable)
      .insert(
        ExpensesTableCompanion.insert(
          profileId: profileId,
          amount: amount,
          description: Value(description),
          occurredOn: Value(date),
          category: Value(category),
        ),
      );

  group('Seleção SQL', () {
    test(
      'SuggestionsDao usa uma consulta sem paginação nem transação explícita',
      () async {
        final id = await insert();
        interceptor.beforeCommit = () async =>
            throw StateError('unexpected transaction');

        final records = await dao.get(query: 'mer');

        expect(records.single.id, id);
        expect(interceptor.selects, hasLength(1));
        expect(interceptor.selects.single, contains('row_number()'));
        expect(interceptor.selects.single, isNot(contains('OFFSET')));
        expect(() => records.clear(), throwsUnsupportedError);
      },
    );

    test(
      'usa índice existente por perfil para percorrer o histórico em ordem',
      () async {
        await insert();
        await dao.get(query: 'mercado');
        final sql = interceptor.selects.single;

        final plan = await database
            .customSelect(
              'EXPLAIN QUERY PLAN $sql',
              variables: [Variable.withString('mercado')],
            )
            .get();

        expect(
          plan.map((row) => row.read<String>('detail')).join('\n'),
          contains('expenses_profile_date'),
        );
      },
    );

    test('limita as 30 correspondências antes de deduplicar', () async {
      await insert(description: 'Café antigo', date: '2026-11-01');
      for (int index = 0; index < 30; index++) {
        await insert(description: 'CAFÉ');
      }

      final records = await dao.get(query: 'café');

      expect(records, hasLength(1));
      expect(records.single.description, 'CAFÉ');
    });

    test('retorna até 30 descrições distintas em ordem de data e ID', () async {
      for (int index = 0; index < 35; index++) {
        await insert(description: 'Mercado $index');
      }

      final records = await dao.get(query: 'Mercado');

      expect(records, hasLength(30));
      expect(records.first.description, 'Mercado 34');
      expect(records.last.description, 'Mercado 5');
    });

    test(
      'mantém todos os campos da ocorrência mais recente de cada descrição',
      () async {
        await insert(
          description: 'Café',
          date: '2026-11-01',
          amount: 500,
          category: 'food',
        );
        final newest = await insert(
          description: 'CAFÉ',
          amount: 200,
          category: 'other',
        );

        final record = (await dao.get(query: 'café')).single;

        expect(record.id, newest);
        expect(record.description, 'CAFÉ');
        expect(record.amount, 200);
        expect(record.category, 'other');
        expect(record.profileId, profileId);
      },
    );

    test(
      'prioriza data civil em vez de ID para definir a ocorrência mais recente',
      () async {
        final newestDate = await insert(
          description: 'CAFÉ',
          date: '2026-11-23',
        );
        await insert(description: 'Café', date: '2026-11-01');

        expect((await dao.get(query: 'café')).single.id, newestDate);
      },
    );

    test(
      'encontra correspondência além de centenas de não correspondências',
      () async {
        final id = await insert(description: 'Agulha', date: '2026-11-01');
        for (int index = 0; index < 201; index++) {
          await insert(description: 'Palha');
        }

        expect((await dao.get(query: 'agulha')).single.id, id);
        expect(interceptor.selects, hasLength(1));
      },
    );
  });

  group('Matching literal Unicode', () {
    test(
      'preserva acentos e lowercase Dart sem limitar matching a ASCII',
      () async {
        final id = await insert(description: 'CAFÉ AÇÃO Σ');

        expect((await dao.get(query: 'cAfÉ ação σ')).single.id, id);
        expect(await dao.get(query: 'cafe'), isEmpty);
      },
    );

    for (final query in ['%_\\', "' OR 1=1 --", '[a-z].*']) {
      test('trata "$query" como texto literal vinculado', () async {
        final id = await insert(description: 'Prefixo $query sufixo');
        await insert(description: 'Outro texto');

        expect((await dao.get(query: query)).single.id, id);
      });
    }

    test(
      'query vazia exclui nulos e texto vazio sem remover espaços',
      () async {
        await insert(description: null);
        await insert(description: '');
        final id = await insert(description: ' ');

        expect((await dao.get(query: '')).single.id, id);
      },
    );

    test('sem correspondências retorna lista vazia imutável', () async {
      final records = await dao.get(query: 'ausente');

      expect(records, isEmpty);
      expect(
        () => records.add(
          const ExpensesTableData(
            id: 1,
            profileId: 1,
            amount: 100,
            category: 'other',
            occurredOn: '2026-11-23',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  test('propaga falhas inesperadas sem fallback ou retry', () async {
    final failure = StateError('unexpected');
    interceptor.beforeRead = () async => throw failure;

    await expectLater(dao.get(query: 'mercado'), throwsA(same(failure)));
    expect(interceptor.selects, hasLength(1));
  });
}
