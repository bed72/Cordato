import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';
import '../../../../support/core/mocks/auth_store_mock.dart';
import '../../../../support/core/mocks/home_widget_client_mock.dart';

void main() {
  const attributes = {
    'amount': 1500,
    'description': ' Ônibus e metrô ',
    'category': 'transport',
    'occurred_on': '2026-10-05 00:00:00.000Z',
  };
  const resource = {'id': '8', ...attributes};
  const listing = {
    'items': [resource],
    'page': 1,
    'perPage': 30,
    'totalItems': 2,
    'totalPages': 2,
  };
  late PocketBaseFixture fixture;
  late IExpenseRepository repository;
  late HomeWidgetClientMock homeWidgetClient;

  setUp(() {
    fixture = PocketBaseFixture();
    fixture.authenticate(id: 'owner-id');
    fixture.respond = (_) => PocketBaseFixture.jsonResponse(resource);
    homeWidgetClient = HomeWidgetClientMock();
    repository = ExpenseRepository(
      pocketBase: fixture.client,
      homeWidgetClient: homeWidgetClient,
    );
    addTearDown(fixture.client.close);
  });

  Map<String, dynamic> bodyOf(http.Request request) => request.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(request.body) as Map<String, dynamic>;

  group('Individual records and mutations', () {
    for (final operation in ['create', 'update', 'delete']) {
      test(
        '$operation notifies the widget only after remote success',
        () async {
          final response = Completer<http.Response>();
          final started = Completer<void>();
          fixture.respond = (_) {
            started.complete();
            return response.future;
          };

          final pending = switch (operation) {
            'create' => repository.create(cents: 1500, description: 'Mercado'),
            'update' => repository.update(id: '8', cents: 1500),
            _ => repository.delete(id: '8'),
          };
          await started.future;
          verifyNever(homeWidgetClient.requestMonthlyRefresh);

          response.complete(switch (operation) {
            'delete' => http.Response('', 204),
            _ => PocketBaseFixture.jsonResponse(resource),
          });
          await pending;

          verify(homeWidgetClient.requestMonthlyRefresh).called(1);
        },
      );
    }

    test(
      'reads the encoded ID and maps the remote record without synchronization',
      () async {
        const id = ' a/b?c#d ';

        final expense = await repository.getById(id: id);

        expect(expense.id, '8');
        expect(expense.cents.cents, 1500);
        expect(expense.description, ' Ônibus e metrô ');
        expect(expense.category, ExpenseCategoryEnum.transport);
        expect(expense.occurredOn, DateTime(2026, 10, 5));
        final request = fixture.requests.single;
        expect(request.method, 'GET');
        expect(request.url.pathSegments.last, id);
        expect(request.url.query, isEmpty);
        expect(request.url.fragment, isEmpty);
        expect(request.body, isEmpty);
        expect(request.headers['Authorization'], PocketBaseFixture.token);
        verifyNever(homeWidgetClient.requestMonthlyRefresh);
      },
    );

    for (final owner in <String?>[null, '', '   ']) {
      test('rejects missing auth owner "$owner" before HTTP', () async {
        if (owner == null) {
          fixture.client.authStore.clear();
        } else {
          fixture.authenticate(id: owner);
        }

        await expectLater(
          repository.create(cents: 100, description: 'Game'),
          throwsA(isA<MissingAuthenticatedUserException>()),
        );

        expect(fixture.requests, isEmpty);
        verifyNever(homeWidgetClient.requestMonthlyRefresh);
      });
    }

    test('preserves the original auth ID without trimming', () async {
      fixture.authenticate(id: ' owner-id ');

      await repository.create(cents: 100, description: 'Game');

      expect(bodyOf(fixture.requests.single)['owner'], ' owner-id ');
    });

    test('reads the current owner for each creation without caching', () async {
      await repository.create(cents: 100, description: 'First');
      fixture.authenticate(id: 'new-owner');
      await repository.create(cents: 100, description: 'Second');

      expect(fixture.requests.map((request) => bodyOf(request)['owner']), [
        'owner-id',
        'new-owner',
      ]);
    });

    test('propagates auth record lookup failures without HTTP', () async {
      final store = AuthStoreMock();
      final failure = StateError('auth record unavailable');
      when(() => store.record).thenThrow(failure);
      final client = PocketBase(
        fixture.client.baseURL,
        authStore: store,
        httpClientFactory: fixture.client.httpClientFactory,
      );
      addTearDown(client.close);
      final failingRepository = ExpenseRepository(
        pocketBase: client,
        homeWidgetClient: homeWidgetClient,
      );

      await expectLater(
        failingRepository.create(cents: 100, description: 'Game'),
        throwsA(same(failure)),
      );

      expect(fixture.requests, isEmpty);
      verifyNever(homeWidgetClient.requestMonthlyRefresh);
    });

    test(
      'creates a native record with owner, default category and civil UTC date',
      () async {
        final expense = await repository.create(
          cents: 9007199254740991,
          description: ' Game ',
          occurredOn: DateTime.utc(2026, 9, 1, 23),
        );

        expect(expense.cents.cents, 1500);
        final request = fixture.requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/collections/expenses/records');
        expect(bodyOf(request), {
          'owner': 'owner-id',
          'category': 'other',
          'amount': 9007199254740991,
          'description': ' Game ',
          'occurred_on': '2026-09-01 00:00:00.000Z',
        });
        expect(request.url.query, isEmpty);
      },
    );

    for (final category in ExpenseCategoryEnum.values) {
      test('creates with the persisted ${category.value} category', () async {
        final expense = await repository.create(
          cents: 1500,
          description: ' Original ',
          category: category,
          occurredOn: DateTime(2026, 10, 5),
        );

        expect(bodyOf(fixture.requests.single), {
          'owner': 'owner-id',
          'amount': 1500,
          'description': ' Original ',
          'category': category.value,
          'occurred_on': '2026-10-05 00:00:00.000Z',
        });
        expect(expense.category, ExpenseCategoryEnum.transport);
      });

      test(
        'patches only ${category.value} without requiring an auth owner',
        () async {
          fixture.client.authStore.clear();

          final expense = await repository.update(id: '8', category: category);

          final request = fixture.requests.single;
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/collections/expenses/records/8');
          expect(bodyOf(request), {'category': category.value});
          expect(expense.category, ExpenseCategoryEnum.transport);
        },
      );
    }

    test('uses the current civil date only when create has no date', () async {
      final before = DateTime.now();

      await repository.create(cents: 100, description: 'Game');

      final after = DateTime.now();
      final date = DateTime.parse(
        bodyOf(fixture.requests.single)['occurred_on'] as String,
      );
      expect(
        date.isBefore(DateTime.utc(before.year, before.month, before.day)),
        isFalse,
      );
      expect(
        date.isAfter(DateTime.utc(after.year, after.month, after.day)),
        isFalse,
      );
    });

    for (final input in [
      (
        cents: 0,
        description: ' Novo nome ',
        date: DateTime.utc(2026, 9, 30, 23),
      ),
      (cents: null, description: null, date: null),
    ]) {
      test('patches only supplied attributes: $input', () async {
        final expense = await repository.update(
          id: 'a/b',
          cents: input.cents,
          description: input.description,
          occurredOn: input.date,
        );

        expect(expense.id, '8');
        final request = fixture.requests.single;
        expect(request.method, 'PATCH');
        expect(request.url.pathSegments.last, 'a/b');
        expect(bodyOf(request), {
          'amount': ?input.cents,
          'description': ?input.description,
          if (input.date != null) 'occurred_on': '2026-09-30 00:00:00.000Z',
        });
        expect(request.url.query, isEmpty);
      });
    }

    for (final status in [200, 201, 202, 204]) {
      test('uses native SDK deletion success semantics for $status', () async {
        fixture.respond = (_) => http.Response('', status);

        await repository.delete(id: 'a/b?c#d');

        final request = fixture.requests.single;
        expect(request.method, 'DELETE');
        expect(request.url.pathSegments.last, 'a/b?c#d');
        expect(request.url.query, isEmpty);
        expect(request.body, isEmpty);
        verify(homeWidgetClient.requestMonthlyRefresh).called(1);
      });
    }
  });

  group('Listing, filters and pagination', () {
    setUp(
      () => fixture.respond = (_) => PocketBaseFixture.jsonResponse(listing),
    );

    test(
      'escapes category filter values without allowing new expressions',
      () async {
        await repository.get(category: 'food" || amount > 0 \\');

        expect(
          fixture.requests.single.url.queryParameters['filter'],
          r'category = "food\" || amount > 0 \\"',
        );
      },
    );

    for (final date in [
      (end: DateTime(2028, 2, 29), next: '2028-03-01'),
      (end: DateTime(2026, 12, 31), next: '2027-01-01'),
    ]) {
      test('uses exclusive next-day bound after ${date.end}', () async {
        await repository.get(to: date.end);

        expect(
          fixture.requests.single.url.queryParameters['filter'],
          'occurred_on < "${date.next} 00:00:00.000Z"',
        );
      });
    }

    test('preserves response order and returns the next page number', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({
        ...listing,
        'items': [
          resource,
          {'id': '2', ...attributes},
        ],
        'page': 2,
        'totalPages': 3,
      });

      final page = await repository.get(page: 2);

      expect(page.items.map((item) => item.id), ['8', '2']);
      expect(page.nextPage, 3);
      expect(() => page.items.clear(), throwsUnsupportedError);
      expect(fixture.requests.single.url.queryParameters['page'], '2');
      verifyNever(homeWidgetClient.requestMonthlyRefresh);
    });

    for (final size in [0, -1, 6, 20]) {
      test(
        'accepts empty pages and preserves the page-size fallback for $size',
        () async {
          fixture.respond = (_) => PocketBaseFixture.jsonResponse({
            'items': [],
            'page': 1,
            'totalPages': 0,
          });

          final page = await repository.get(pageSize: size);

          expect(page.items, isEmpty);
          expect(page.nextPage, isNull);
          expect(
            fixture.requests.single.url.queryParameters['perPage'],
            '${size > 0 ? size : 30}',
          );
        },
      );
    }

    test(
      'applies explicit civil period, category and sort to the requested page',
      () async {
        await repository.get(
          pageSize: 20,
          category: 'food',
          sort: 'occurred_on',
          from: DateTime.utc(2026, 9, 1, 23),
          to: DateTime(2026, 9, 30, 12),
          page: 2,
        );

        expect(fixture.requests.single.url.queryParameters, {
          'page': '2',
          'perPage': '20',
          'sort': 'occurred_on',
          'skipTotal': 'false',
          'filter': 'category = "food" && occurred_on >= "2026-09-01 00:00:00.000Z" && occurred_on < "2026-10-01 00:00:00.000Z"',
        });
      },
    );

    for (final limits in [
      (
        from: DateTime.utc(2026, 9, 1, 23),
        to: null,
        filter: 'occurred_on >= "2026-09-01 00:00:00.000Z"',
      ),
      (
        from: null,
        to: DateTime(2026, 9, 30, 12),
        filter: 'occurred_on < "2026-10-01 00:00:00.000Z"',
      ),
    ]) {
      test(
        'does not complete incomplete civil intervals: ${limits.filter}',
        () async {
          await repository.get(from: limits.from, to: limits.to);

          expect(
            fixture.requests.single.url.queryParameters['filter'],
            limits.filter,
          );
        },
      );
    }

    for (final pageNumber in [1, 2, 3]) {
      test('derives the next page for page $pageNumber of 3', () async {
        fixture.respond = (_) => PocketBaseFixture.jsonResponse({
          ...listing,
          'page': pageNumber,
          'totalPages': 3,
        });

        final page = await repository.get(page: pageNumber);

        expect(page.nextPage, pageNumber < 3 ? pageNumber + 1 : null);
      });
    }

    for (final malformed in [
      {'items': [], 'page': '1', 'totalPages': 1},
      {
        'items': [null],
        'page': 1,
        'totalPages': 1,
      },
    ]) {
      test('propagates invalid native page data: $malformed', () async {
        fixture.respond = (_) => PocketBaseFixture.jsonResponse(malformed);

        await expectLater(repository.get(), throwsA(isA<TypeError>()));
      });
    }
  });

  group('Suggestions', () {
    test('uses filtered recent history and deduplicates descriptions ignoring case', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({
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
      });
      const query = r" [Demo] Aluguél ' || amount > 0 \ & ?/# ";

      final suggestions = await repository.suggestions(query: query);

      expect(suggestions.map((item) => item.id), ['rent', 'market']);
      expect(suggestions.map((item) => item.cents), [160000, 20000]);
      expect(suggestions.map((item) => item.category), [
        ExpenseCategoryEnum.housing,
        ExpenseCategoryEnum.food,
      ]);
      expect(() => suggestions.clear(), throwsUnsupportedError);
      final request = fixture.requests.single;
      expect(request.url.path, '/api/collections/expenses/records');
      expect(request.url.queryParameters, {
        'page': '1',
        'perPage': '30',
        'sort': '-occurred_on,-created,-id',
        'filter':
            r'''description ~ " [Demo] Aluguél ' || amount > 0 \\ & ?/# "''',
        'skipTotal': 'true',
        'fields': 'id,description,amount,category',
      });
      expect(request.body, isEmpty);
      verifyNever(homeWidgetClient.requestMonthlyRefresh);
    });

    test('empty suggestions succeed', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({'items': []});

      expect(await repository.suggestions(query: 'Mer'), isEmpty);
    });

    test('uses native SDK defaults for absent list items', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({});

      expect(await repository.suggestions(query: 'Mer'), isEmpty);
    });

    for (final items in [
      <String, dynamic>{},
      [
        {'id': 'bad', 'description': 10, 'amount': 100},
      ],
    ]) {
      test('malformed suggestions propagate: $items', () async {
        fixture.respond = (_) =>
            PocketBaseFixture.jsonResponse({'items': items});

        await expectLater(
          repository.suggestions(query: 'Mer'),
          throwsA(isA<TypeError>()),
        );
      });
    }

    test(
      'invalid historical category propagates without a partial response',
      () async {
        fixture.respond = (_) => PocketBaseFixture.jsonResponse({
          'items': [
            resource,
            {...resource, 'id': 'invalid', 'category': 'unknown'},
          ],
        });

        await expectLater(
          repository.suggestions(query: 'Mer'),
          throwsStateError,
        );
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
          _ => throw StateError('Unknown expense operation'),
        };
      }

      Map<String, dynamic> payload(Map<String, dynamic> record) =>
          switch (operation) {
            'get' || 'suggestions' => {
              ...listing,
              'items': [record],
            },
            _ => record,
          };

      test(
        '$operation preserves native error order, status, code, pointer and parameter',
        () async {
          fixture.respond = (_) => PocketBaseFixture.jsonResponse({
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
          }, status: 400);

          await expectLater(
            execute(),
            throwsA(
              isA<ExpenseException>().having(
                (failure) => failure.errors.errors
                    .map(
                      (error) => (
                        error.status,
                        error.code,
                        error.pointer,
                        error.parameter,
                        error.detail,
                      ),
                    )
                    .toList(),
                'ordered metadata',
                [
                  (
                    '400',
                    'validation_min_greater_equal_than_required',
                    '/amount',
                    'amount',
                    'Invalid amount.',
                  ),
                  (
                    '400',
                    'validation_length_out_of_range',
                    '/description',
                    'description',
                    'Invalid description.',
                  ),
                  (
                    '400',
                    'validation_in_invalid',
                    '/category',
                    'category',
                    'Invalid category.',
                  ),
                ],
              ),
            ),
          );
          verifyNever(homeWidgetClient.requestMonthlyRefresh);
        },
      );

      for (final status in [401, 403, 404, 422, 503]) {
        test(
          '$operation maps HTTP $status without managing sessions or notifying the widget',
          () async {
            fixture.respond = (_) => PocketBaseFixture.jsonResponse({
              'message': 'Remote failure',
            }, status: status);
            final record = fixture.client.authStore.record;

            await expectLater(
              execute(),
              throwsA(
                isA<ExpenseException>().having(
                  (failure) => failure.errors.errors.single.status,
                  'status',
                  '$status',
                ),
              ),
            );

            expect(fixture.client.authStore.token, PocketBaseFixture.token);
            expect(fixture.client.authStore.record, same(record));
            verifyNever(homeWidgetClient.requestMonthlyRefresh);
          },
        );
      }

      for (final response in <Map<String, dynamic>>[
        {},
        {'errors': []},
        {'errors': 'invalid'},
      ]) {
        test(
          '$operation preserves HTTP status when field errors are absent: $response',
          () async {
            fixture.respond = (_) =>
                PocketBaseFixture.jsonResponse(response, status: 503);

            await expectLater(
              execute(),
              throwsA(
                isA<ExpenseException>().having(
                  (failure) => failure.errors.errors.single.status,
                  'status',
                  '503',
                ),
              ),
            );
          },
        );
      }

      test('$operation maps transport failures to a safe fallback', () async {
        fixture.respond = (_) => throw const SocketException('offline');

        await expectLater(
          execute(),
          throwsA(
            isA<ExpenseException>().having(
              (failure) => failure.errors.errors.single.title,
              'title',
              'Erro desconhecido',
            ),
          ),
        );

        expect(fixture.client.authStore.token, PocketBaseFixture.token);
        verifyNever(homeWidgetClient.requestMonthlyRefresh);
      });

      for (final failure in [
        StateError('private detail'),
        const FormatException('invalid payload'),
      ]) {
        for (final synchronous in [true, false]) {
          test(
            '$operation propagates ${failure.runtimeType} unchanged (synchronous: $synchronous)',
            () async {
              fixture.respond = (_) {
                if (synchronous) {
                  throw failure;
                }
                return Future<http.Response>.error(failure);
              };

              await expectLater(execute(), throwsA(same(failure)));

              verifyNever(homeWidgetClient.requestMonthlyRefresh);
            },
          );
        }
      }

      test('$operation waits for SDK completion', () async {
        final response = Completer<http.Response>();
        final started = Completer<void>();
        fixture.respond = (_) {
          started.complete();
          return response.future;
        };
        var completed = false;
        final pending = execute().then((value) {
          completed = true;
          return value;
        });
        await started.future;

        expect(completed, isFalse);
        response.complete(switch (operation) {
          'delete' => http.Response('', 204),
          _ => PocketBaseFixture.jsonResponse(payload(resource)),
        });
        await pending;

        expect(completed, isTrue);
      });

      if (operation == 'delete') {
        continue;
      }

      for (final malformed in [
        'shape',
        'date',
        'category',
        'amount',
        'fraction',
      ]) {
        if (operation == 'suggestions' &&
            (malformed == 'date' || malformed == 'amount')) {
          continue;
        }
        test(
          '$operation propagates invalid $malformed without partial success or widget notification',
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
            fixture.respond = (_) =>
                PocketBaseFixture.jsonResponse(switch (operation) {
                  'get' || 'suggestions' => {
                    ...listing,
                    'items': [resource, invalid],
                  },
                  _ => invalid,
                });

            await expectLater(
              execute(),
              throwsA(switch (malformed) {
                'date' => isA<FormatException>(),
                'category' => isA<StateError>(),
                'amount' => isA<ArgumentError>(),
                _ => isA<TypeError>(),
              }),
            );

            verifyNever(homeWidgetClient.requestMonthlyRefresh);
          },
        );
      }

      test('$operation preserves large integer cents in responses', () async {
        fixture.respond = (_) => PocketBaseFixture.jsonResponse(
          payload({...resource, 'amount': 9007199254740991}),
        );

        final confirmedExpenses = await execute();

        final cents = switch (confirmedExpenses) {
          List<ExpenseSuggestionEntity>() => confirmedExpenses.single.cents,
          ExpenseEntity() => confirmedExpenses.cents.cents,
          ExpensePageEntity() => confirmedExpenses.items.single.cents.cents,
          _ => throw StateError('Unexpected expense response'),
        };
        expect(cents, 9007199254740991);
      });
    }
  });
}
