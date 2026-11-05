import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  const attributes = {
    'amount': 1500,
    'description': ' Ônibus e metrô ',
    'category': 'transport',
    'occurred_on': '2026-10-05 00:00:00.000Z',
  };
  const resource = {'id': '8', ...attributes};
  const single = Responses(status: 200, body: resource);
  const listing = Responses(
    status: 200,
    body: {
      'items': [resource],
      'page': 1,
      'totalPages': 2,
    },
  );
  late HttpClientMock client;
  late StorageClientMock storage;
  late IExpenseRepository repository;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    storage = StorageClientMock();
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => 'owner-id');
    repository = ExpenseRepository(httpClient: client, storageClient: storage);
  });

  Future<ErrorsEntity> errorsOf(Future<Object?> operation) async {
    try {
      await operation;
      fail('Expected ExpenseException');
    } on ExpenseException catch (exception) {
      return exception.errors;
    }
  }

  group('Individual records and mutations', () {
    for (final owner in [null, '', '   ']) {
      test('rejects missing owner "$owner" before HTTP', () async {
        when(() => storage.read(key: StorageKeyEnum.userId.key))
            .thenAnswer((_) async => owner);
        await expectLater(
          repository.create(cents: 100, description: 'Game'),
          throwsA(isA<ExpenseException>()),
        );
        verifyZeroInteractions(client);
      });
    }

    test('awaits owner lookup and preserves the original stored ID', () async {
      final pending = Completer<String?>();
      when(() => storage.read(key: StorageKeyEnum.userId.key))
          .thenAnswer((_) => pending.future);
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => single);
      final creation = repository.create(cents: 100, description: 'Game');
      verifyZeroInteractions(client);
      pending.complete(' owner-id ');
      await creation;
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.body!['owner'], ' owner-id ');
    });

    test('reads the current owner for each creation without caching', () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => single);
      await repository.create(cents: 100, description: 'First');
      when(() => storage.read(key: StorageKeyEnum.userId.key))
          .thenAnswer((_) async => 'new-owner');
      await repository.create(cents: 100, description: 'Second');
      final requests = verify(
        () => client.post(parameter: captureAny(named: 'parameter')),
      ).captured.cast<Requests>();
      expect(requests.map((request) => request.body!['owner']), [
        'owner-id',
        'new-owner',
      ]);
    });

    test('propagates owner storage failures without HTTP', () async {
      final failure = StateError('storage unavailable');
      when(() => storage.read(key: StorageKeyEnum.userId.key))
          .thenAnswer((_) async => throw failure);
      await expectLater(
        repository.create(cents: 100, description: 'Game'),
        throwsA(same(failure)),
      );
      verifyZeroInteractions(client);
    });

    test('reads an encoded id with no body, query or custom headers', () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => single);
      final expense = await repository.getById(id: ' a/b?c#d ');
      expect(expense.id, '8');
      expect(expense.cents.cents, 1500);
      expect(expense.description, ' Ônibus e metrô ');
      expect(expense.category, ExpenseCategoryEnum.transport);
      expect(expense.occurredOn, DateTime(2026, 10, 5));
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(
        request.path,
        'collections/expenses/records/${Uri.encodeComponent(' a/b?c#d ')}',
      );
      expect(request.body, isNull);
      expect(request.query, isNull);
      expect(request.headers, isNull);
      verifyNoMoreInteractions(client);
    });

    test(
      'creates a native record with owner, default category and civil UTC date',
      () async {
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => single);
        final expense = await repository.create(
          cents: 9007199254740991,
          description: ' Game ',
          occurredOn: DateTime.utc(2026, 9, 1, 23),
        );
        expect(expense.cents.cents, 1500);
        final request =
            verify(() => client.post(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.path, 'collections/expenses/records');
        expect(request.body, {
          'owner': 'owner-id',
          'category': 'other',
          'amount': 9007199254740991,
          'description': ' Game ',
          'occurred_on': '2026-09-01 00:00:00.000Z',
        });
        expect(request.query, isNull);
        expect(request.headers, isNull);
        verifyNoMoreInteractions(client);
        verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(1);
        verifyNoMoreInteractions(storage);
      },
    );

    for (final category in ExpenseCategoryEnum.values) {
      test('creates with the persisted ${category.value} category', () async {
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => single);

        final expense = await repository.create(
          cents: 1500,
          description: ' Original ',
          category: category,
          occurredOn: DateTime(2026, 10, 5),
        );

        final request =
            verify(() => client.post(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.body, {
          'owner': 'owner-id',
          'amount': 1500,
          'description': ' Original ',
          'category': category.value,
          'occurred_on': '2026-10-05 00:00:00.000Z',
        });
        expect(expense.category, ExpenseCategoryEnum.transport);
      });

      test(
        'patches only the ${category.value} category without reading storage',
        () async {
          when(() => client.patch(parameter: any(named: 'parameter')))
              .thenAnswer((_) async => single);

          final expense = await repository.update(id: '8', category: category);

          final request =
              verify(
                    () =>
                        client.patch(parameter: captureAny(named: 'parameter')),
                  ).captured.single
                  as Requests;
          expect(request.path, 'collections/expenses/records/8');
          expect(request.body, {'category': category.value});
          expect(expense.category, ExpenseCategoryEnum.transport);
          verifyZeroInteractions(storage);
        },
      );
    }

    test('uses the current civil date only when create has no date', () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => single);
      final before = DateTime.now();
      await repository.create(cents: 100, description: 'Game');
      final after = DateTime.now();
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      final date = DateTime.parse(request.body!['occurred_on'] as String);
      expect(
        date.isBefore(DateTime.utc(before.year, before.month, before.day)),
        isFalse,
      );
      expect(
        date.isAfter(DateTime.utc(after.year, after.month, after.day)),
        isFalse,
      );
    });

    test(
      'patches only supplied attributes and preserves id and description',
      () async {
        when(() => client.patch(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => single);
        for (final input in [
          (
            cents: 0,
            description: ' Novo nome ',
            date: DateTime.utc(2026, 9, 30, 23),
          ),
          (cents: null, description: null, date: null),
        ]) {
          expect(
            (await repository.update(
              id: 'a/b',
              cents: input.cents,
              description: input.description,
              occurredOn: input.date,
            )).id,
            '8',
          );
          final request =
              verify(
                    () =>
                        client.patch(parameter: captureAny(named: 'parameter')),
                  ).captured.single
                  as Requests;
          expect(request.path, 'collections/expenses/records/a%2Fb');
          expect(request.body, {
            'amount': ?input.cents,
            'description': ?input.description,
            if (input.date != null) 'occurred_on': '2026-09-30 00:00:00.000Z',
          });
          expect(request.headers, isNull);
          expect(request.query, isNull);
        }
      },
    );

    test(
      'deletion concludes only on 204 and encodes the original id',
      () async {
        when(() => client.delete(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => const Responses(status: 204, body: {}));
        await repository.delete(id: 'a/b?c#d');
        final request =
            verify(
                  () =>
                      client.delete(parameter: captureAny(named: 'parameter')),
                ).captured.single
                as Requests;
        expect(request.path, 'collections/expenses/records/a%2Fb%3Fc%23d');
        expect(request.body, isNull);
        expect(request.query, isNull);
        expect(request.headers, isNull);
        for (final status in [200, 201, 202]) {
          when(() => client.delete(parameter: any(named: 'parameter')))
              .thenAnswer((_) async => Responses(status: status, body: {}));
          await expectLater(
            repository.delete(id: '8'),
            throwsA(isA<ExpenseException>()),
          );
        }
      },
    );
  });

  group('Listing, filters and pagination', () {
    test(
      'escapes category filter values without allowing new expressions',
      () async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => listing);
        await repository.get(category: 'food" || amount > 0 \\');
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(
          request.query!['filter'],
          r'category = "food\" || amount > 0 \\"',
        );
      },
    );

    for (final date in [
      (end: DateTime(2028, 2, 29), next: '2028-03-01'),
      (end: DateTime(2026, 12, 31), next: '2027-01-01'),
    ]) {
      test('uses exclusive next-day bound after ${date.end}', () async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => listing);
        await repository.get(to: date.end);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(
          request.query!['filter'],
          'occurred_on < "${date.next} 00:00:00.000Z"',
        );
      });
    }

    test(
      'preserves response order and builds immutable native page continuations',
      () async {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(
            status: 200,
            body: {
              'items': [
                resource,
                {'id': '2', ...attributes},
              ],
              'page': 2,
              'totalPages': 3,
            },
          ),
        );
        final page = await repository.get();
        expect(page.items.map((item) => item.id), ['8', '2']);
        expect(Uri.parse(page.next!).queryParameters, {
          'page': '3',
          'perPage': '30',
          'sort': '-occurred_on,-id',
        });
        expect(Uri.parse(page.prev!).queryParameters['page'], '1');
        expect(() => page.items.clear(), throwsUnsupportedError);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.path, 'collections/expenses/records');
        expect(request.query, {
          'page': 1,
          'perPage': 30,
          'sort': '-occurred_on,-id',
        });
        expect(request.headers, isNull);
      },
    );

    test('accepts empty pages and preserves the page-size fallback', () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {'items': [], 'page': 1, 'totalPages': 0},
        ),
      );
      for (final size in [0, -1, 6, 20]) {
        final page = await repository.get(pageSize: size);
        expect(page.items, isEmpty);
        expect(page.next, isNull);
        expect(page.prev, isNull);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.query, {
          'page': 1,
          'perPage': size > 0 ? size : 30,
          'sort': '-occurred_on,-id',
        });
      }
    });

    test(
      'extracts continuation queries without following remote hosts or paths',
      () async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => listing);
        for (final link in [
          'https://other.example/ignored?page=2&perPage=20&expand=owner',
          'ignored?page=2&perPage=20',
          '?page=2&perPage=20',
        ]) {
          await repository.get(pageSize: 6, pageLink: link);
          final request =
              verify(
                    () => client.get(parameter: captureAny(named: 'parameter')),
                  ).captured.single
                  as Requests;
          expect(request.path, 'collections/expenses/records');
          expect(request.query, {
            'page': 2,
            'perPage': 6,
            'sort': '-occurred_on,-id',
          });
        }
      },
    );

    test(
      'replaces continuation filters with explicit civil period and category',
      () async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => listing);
        await repository.get(
          pageSize: 20,
          category: 'food',
          sort: 'occurred_on',
          from: DateTime.utc(2026, 9, 1, 23),
          to: DateTime(2026, 9, 30, 12),
          pageLink: '?page=2&perPage=6&sort=-occurred_on&filter=category%3D%27travel%27',
        );
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.path, 'collections/expenses/records');
        expect(request.query, {
          'page': 2,
          'perPage': 20,
          'sort': 'occurred_on',
          'filter': 'category = "food" && occurred_on >= "2026-09-01 00:00:00.000Z" && occurred_on < "2026-10-01 00:00:00.000Z"',
        });
      },
    );

    test(
      'preserves continuation filters when no explicit filters are supplied',
      () async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => listing);
        final first = await repository.get(
          category: 'food',
          sort: 'occurred_on',
        );
        await repository.get(pageLink: first.next);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .last
                as Requests;
        expect(request.query, {
          'page': 2,
          'perPage': 30,
          'filter': 'category = "food"',
          'sort': 'occurred_on',
        });
      },
    );

    test('does not complete incomplete civil intervals', () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => listing);
      for (final limits in [
        (from: DateTime.utc(2026, 9, 1, 23), to: null),
        (from: null, to: DateTime(2026, 9, 30, 12)),
      ]) {
        await repository.get(from: limits.from, to: limits.to);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.query, {
          'page': 1,
          'perPage': 30,
          'sort': '-occurred_on,-id',
          if (limits.from != null)
            'filter': 'occurred_on >= "2026-09-01 00:00:00.000Z"',
          if (limits.to != null)
            'filter': 'occurred_on < "2026-10-01 00:00:00.000Z"',
        });
      }
    });

    test(
      'invalid continuations fail before HTTP without being masked',
      () async {
        for (final link in [
          '',
          'expenses',
          '?page=2#fragment',
          '?page=0',
          '?page=-1',
          '?page=abc',
        ]) {
          await expectLater(
            repository.get(pageLink: link),
            throwsFormatException,
          );
        }
        verifyZeroInteractions(client);
      },
    );
  });

  group('Suggestions', () {
    test(
      'invalid historical category propagates without a partial result',
      () async {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(
            status: 200,
            body: {
              'items': [
                {
                  'id': 'market',
                  'description': 'Mercado',
                  'amount': 20000,
                  'category': 'food',
                },
                {
                  'id': 'invalid',
                  'description': 'Outro registro',
                  'amount': 100,
                  'category': 'unknown',
                },
              ],
            },
          ),
        );

        await expectLater(
          repository.suggestions(query: 'Mer'),
          throwsStateError,
        );
        verifyZeroInteractions(storage);
      },
    );

    test('suggestions use filtered history and keep the most recent description ignoring case', () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'items': [
              {
                'id': 'rent',
                'description': 'Aluguel',
                'amount': 160000,
                'category': 'housing',
              },
              {
                'id': 'market',
                'description': 'Mercado',
                'amount': 20000,
                'category': 'food',
              },
              {
                'id': 'old-rent',
                'description': 'ALUGUEL',
                'amount': 150000,
                'category': 'other',
              },
            ],
          },
        ),
      );
      const query = r" [Demo] Aluguél ' || amount > 0 \ & ?/# ";
      final suggestions = await repository.suggestions(query: query);
      expect(suggestions.map((item) => item.id), ['rent', 'market']);
      expect(suggestions.map((item) => item.cents), [160000, 20000]);
      expect(suggestions.map((item) => item.category), [
        ExpenseCategoryEnum.housing,
        ExpenseCategoryEnum.food,
      ]);
      expect(() => suggestions.clear(), throwsUnsupportedError);
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/expenses/records');
      expect(request.query, {
        'page': 1,
        'perPage': 30,
        'sort': '-occurred_on,-created,-id',
        'filter':
            r'''description ~ " [Demo] Aluguél ' || amount > 0 \\ & ?/# "''',
        'skipTotal': true,
        'fields': 'id,description,amount,category',
      });
      expect(request.body, isNull);
      expect(request.headers, isNull);
    });

    test(
      'empty suggestions succeed but malformed suggestions propagate',
      () async {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(status: 200, body: {'items': []}),
        );
        expect(await repository.suggestions(query: 'Mer'), isEmpty);
        for (final data in [
          null,
          {},
          [
            {'id': 'bad', 'description': 10, 'amount': 100},
          ],
        ]) {
          when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
            (_) async => Responses(status: 200, body: {'items': data}),
          );
          await expectLater(
            repository.suggestions(query: 'Mer'),
            throwsA(isA<TypeError>()),
          );
        }
      },
    );
  });

  group('Shared failures and pending operations', () {
    for (final operation in [
      'getById',
      'get',
      'create',
      'update',
      'delete',
      'suggestions',
    ]) {
      Future<Object?> execute() async {
        if (operation == 'delete') {
          await repository.delete(id: '8');
          return null;
        }
        return switch (operation) {
          'getById' => repository.getById(id: '8'),
          'get' => repository.get(),
          'suggestions' => repository.suggestions(query: 'Mer'),
          'create' => repository.create(
            cents: 0,
            description: ' Original ',
            category: .transport,
          ),
          'update' => repository.update(
            id: '8',
            cents: 0,
            category: .transport,
          ),
          _ => throw StateError(operation),
        };
      }

      void stub(Future<Responses> Function() answer) {
        switch (operation) {
          case 'getById' || 'get' || 'suggestions':
            when(() => client.get(parameter: any(named: 'parameter')))
                .thenAnswer((_) => answer());
          case 'create':
            when(() => client.post(parameter: any(named: 'parameter')))
                .thenAnswer((_) => answer());
          case 'update':
            when(() => client.patch(parameter: any(named: 'parameter')))
                .thenAnswer((_) => answer());
          case 'delete':
            when(() => client.delete(parameter: any(named: 'parameter')))
                .thenAnswer((_) => answer());
        }
      }

      test(
        '$operation preserves ordered HTTP errors and all metadata',
        () async {
          final exception = HttpResponseException(
            status: 422,
            errors: const ErrorsResponse(
              errors: [
                ErrorResponse(
                  status: '422',
                  title: 'Valor inválido',
                  detail: 'Informe o valor.',
                  pointer: '/data/attributes/amount',
                  parameter: 'filter[from]',
                ),
                ErrorResponse(
                  status: '403',
                  title: 'Sem permissão',
                  detail: 'Outro erro.',
                ),
              ],
            ),
          );
          stub(() async => throw exception);
          final errors = (await errorsOf(execute())).errors;
          expect(errors.map((error) => error.title), [
            'Valor inválido',
            'Sem permissão',
          ]);
          expect(errors.first.status, '422');
          expect(errors.first.detail, 'Informe o valor.');
          expect(errors.first.pointer, '/data/attributes/amount');
          expect(errors.first.parameter, 'filter[from]');
          expect(errors.last.status, '403');
          expect(errors.last.detail, 'Outro erro.');
        },
      );

      test('$operation preserves PocketBase field error metadata', () async {
        stub(
          () async => throw HttpResponseException.fromResponse(
            const Responses(
              status: 400,
              body: {
                'status': 400,
                'message': 'Failed to save record.',
                'data': {
                  'amount': {
                    'code': 'validation_min_greater_equal_than_required',
                    'message': 'Invalid amount.',
                  },
                  'description': {
                    'code': 'validation_length_out_of_range',
                    'message': 'Invalid description.',
                  },
                  'category': {
                    'code': 'validation_in_invalid',
                    'message': 'Invalid category.',
                  },
                },
              },
            ),
          ),
        );
        final errors = (await errorsOf(execute())).errors;
        expect(errors.map((error) => error.pointer), [
          '/amount',
          '/description',
          '/category',
        ]);
        expect(errors.map((error) => error.parameter), [
          'amount',
          'description',
          'category',
        ]);
        expect(errors.first.status, '400');
        expect(errors.first.detail, 'Invalid amount.');
      });

      test(
        '$operation uses safe fallback for malformed remote errors',
        () async {
          for (final body in <Map<String, dynamic>>[
            {},
            {'errors': []},
            {'errors': 'invalid'},
          ]) {
            stub(
              () async => throw HttpResponseException.fromResponse(
                Responses(status: 503, body: body),
              ),
            );
            expect(
              (await errorsOf(execute())).errors.single.title,
              'Erro desconhecido',
            );
          }
        },
      );

      for (final failure in <HttpClientException>[
        for (final type in HttpExceptionEnum.values)
          HttpTransportException(failure: type),
        HttpInvalidResponseException(status: 200),
        HttpUnexpectedException(),
      ]) {
        test(
          '$operation translates ${failure.runtimeType} into expected failure',
          () async {
            stub(() async => throw failure);
            expect(
              (await errorsOf(execute())).errors.single.title,
              'Erro desconhecido',
            );
          },
        );
      }

      for (final synchronous in [true, false]) {
        test(
          '$operation propagates unexpected failures (synchronous: $synchronous)',
          () async {
            final failure = StateError('private detail');
            stub(() {
              if (synchronous) throw failure;
              return Future.error(failure);
            });
            await expectLater(execute(), throwsA(same(failure)));
          },
        );
      }

      test('$operation waits for HTTP completion', () async {
        final pending = Completer<Responses>();
        stub(() => pending.future);
        var complete = false;
        final pendingOperation = execute().then((value) {
          complete = true;
          return value;
        });
        expect(complete, isFalse);
        pending.complete(
          operation == 'get' || operation == 'suggestions'
              ? listing
              : operation == 'delete'
              ? const Responses(status: 204, body: {})
              : single,
        );
        await pendingOperation;
        expect(complete, isTrue);
      });

      if (operation == 'delete') continue;

      for (final malformed in [
        'shape',
        'date',
        'category',
        'amount',
        'fraction',
      ]) {
        if (operation == 'suggestions' &&
            (malformed == 'date' || malformed == 'category')) {
          continue;
        }
        test(
          '$operation propagates invalid $malformed without partial success',
          () async {
            final invalid = switch (malformed) {
              'shape' => <String, dynamic>{},
              _ => {
                'id': 'invalid',
                ...attributes,
                if (malformed == 'date') 'occurred_on': 'not-a-date',
                if (malformed == 'category') 'category': 'unknown',
                if (malformed == 'amount') 'amount': 0,
                if (malformed == 'fraction') 'amount': 1.5,
              },
            };
            stub(
              () async => Responses(
                status: 200,
                body: operation == 'get' || operation == 'suggestions'
                    ? {
                        'items': [resource, invalid],
                        'page': 1,
                        'totalPages': 1,
                      }
                    : invalid,
              ),
            );
            await expectLater(
              execute(),
              throwsA(switch (malformed) {
                'date' => isA<FormatException>(),
                'category' => isA<StateError>(),
                'amount' => isA<ArgumentError>(),
                _ => isA<TypeError>(),
              }),
            );
          },
        );
      }

      test('$operation preserves large integer cents in responses', () async {
        final large = {...resource, 'amount': 9007199254740991};
        stub(
          () async => Responses(
            status: 200,
            body: operation == 'get' || operation == 'suggestions'
                ? {
                    'items': [large],
                    'page': 1,
                    'totalPages': 1,
                  }
                : large,
          ),
        );
        final confirmedExpenses = await execute();
        if (confirmedExpenses is List<ExpenseSuggestionEntity>) {
          expect(confirmedExpenses.single.cents, 9007199254740991);
          return;
        }
        final expense = confirmedExpenses is ExpenseEntity
            ? confirmedExpenses
            : (confirmedExpenses as ExpensePageEntity).items.single;
        expect(expense.cents.cents, 9007199254740991);
      });
    }
  });
}
