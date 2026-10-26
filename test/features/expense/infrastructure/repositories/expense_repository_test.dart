import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/infrastructure/repositories/expense_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  const attributes = {
    'amount': 1500,
    'description': ' Ônibus e metrô ',
    'category': 'transport',
    'occurred_on': '2026-10-05',
  };
  const resource = {'id': '8', 'type': 'expenses', 'attributes': attributes};
  const single = Responses(status: 200, body: {'data': resource});
  const listing = Responses(
    status: 200,
    body: {
      'data': [resource],
      'links': {'next': '?page[after]=opaque%2Bvalue', 'prev': null},
    },
  );
  late HttpClientMock client;
  late IExpenseRepository repository;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    repository = ExpenseRepository(httpClient: client);
  });

  Future<ErrorsEntity> errorsOf(Future<Object?> operation) async {
    try {
      await operation;
      fail('Expected ExpenseException');
    } on ExpenseException catch (exception) {
      return exception.errors;
    }
  }

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
    expect(request.path, 'expenses/${Uri.encodeComponent(' a/b?c#d ')}');
    expect(request.body, isNull);
    expect(request.query, isNull);
    expect(request.headers, isNull);
    verifyNoMoreInteractions(client);
  });

  test(
    'creates the JSON:API payload unchanged with integer cents and civil date',
    () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => single);
      final expense = await repository.create(
        cents: 9007199254740993,
        description: ' Game ',
        occurredOn: DateTime.utc(2026, 9, 1, 23),
      );
      expect(expense.cents.cents, 1500);
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'expenses');
      expect(request.body, {
        'data': {
          'type': 'expenses',
          'attributes': {
            'amount': 9007199254740993,
            'description': ' Game ',
            'occurred_on': '2026-09-01',
          },
        },
      });
      expect(request.query, isNull);
      expect(request.headers, isNull);
      verifyNoMoreInteractions(client);
    },
  );

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
    final date = DateTime.parse(
      ((request.body!['data'] as Map)['attributes'] as Map)['occurred_on']
          as String,
    );
    expect(
      date.isBefore(DateTime(before.year, before.month, before.day)),
      isFalse,
    );
    expect(date.isAfter(DateTime(after.year, after.month, after.day)), isFalse);
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
                  () => client.patch(parameter: captureAny(named: 'parameter')),
                ).captured.single
                as Requests;
        expect(request.path, 'expenses/a%2Fb');
        expect(request.body, {
          'data': {
            'type': 'expenses',
            'attributes': {
              'amount': ?input.cents,
              'description': ?input.description,
              if (input.date != null) 'occurred_on': '2026-09-30',
            },
          },
        });
        expect(request.headers, isNull);
        expect(request.query, isNull);
      }
    },
  );

  test('deletion concludes only on 204 and encodes the original id', () async {
    when(() => client.delete(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 204, body: {}));
    await repository.delete(id: 'a/b?c#d');
    final request =
        verify(() => client.delete(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'expenses/a%2Fb%3Fc%23d');
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
  });

  test('preserves response order, opaque links and immutable items', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Responses(
        status: 200,
        body: {
          'data': [
            resource,
            {'id': '2', 'attributes': attributes},
          ],
          'links': {
            'next': '?page[after]=opaque%2Bvalue',
            'prev': '?page[before]=previous',
          },
        },
      ),
    );
    final page = await repository.get();
    expect(page.items.map((item) => item.id), ['8', '2']);
    expect(page.next, '?page[after]=opaque%2Bvalue');
    expect(page.prev, '?page[before]=previous');
    expect(() => page.items.clear(), throwsUnsupportedError);
    final request =
        verify(() => client.get(parameter: captureAny(named: 'parameter')))
                .captured
                .single
            as Requests;
    expect(request.path, 'expenses');
    expect(request.query, {'page[size]': 30});
    expect(request.headers, isNull);
  });

  test('accepts empty pages and preserves the page-size fallback', () async {
    when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
      (_) async => const Responses(
        status: 200,
        body: {
          'data': [],
          'links': {'next': null, 'prev': null},
        },
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
      expect(request.query, {'page[size]': size > 0 ? size : 30});
    }
  });

  test(
    'extracts continuation queries without following remote hosts or paths',
    () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => listing);
      for (final link in [
        'https://other.example/ignored?page[after]=abc%2B123&page[size]=20',
        'expenses?page[after]=abc%2B123&page[size]=20',
        '?page[after]=abc%2B123&page[size]=20',
      ]) {
        await repository.get(pageSize: 6, pageLink: link);
        final request =
            verify(() => client.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.path, 'expenses');
        expect(request.query, {'page[after]': 'abc+123', 'page[size]': 6});
      }
    },
  );

  test(
    'reapplies explicit filters while preserving opaque repeated parameters',
    () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => listing);
      await repository.get(
        pageSize: 20,
        category: 'food',
        sort: 'occurred_on',
        from: DateTime.utc(2026, 9, 1, 23),
        to: DateTime(2026, 9, 30, 12),
        pageLink: '?page[after]=abc%2B123&page[size]=6&sort=-occurred_on&filter[category]=travel&filter[category][]=food&filter[category][]=other&filter[from]=2025-01-01&filter[to]=2025-01-31&filter[year]=2025&filter[month]=1&filter[day]=2',
      );
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'expenses');
      expect(request.query, {
        'page[after]': 'abc+123',
        'page[size]': 20,
        'sort': 'occurred_on',
        'filter[category]': 'food',
        'filter[category][]': ['food', 'other'],
        'filter[from]': '2026-09-01',
        'filter[to]': '2026-09-30',
      });
    },
  );

  test(
    'preserves continuation filters when no explicit filters are supplied',
    () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => listing);
      await repository.get(
        pageLink: '?page[number]=2&filter[year]=2026&filter[month]=9&filter[day]=1&filter[category]=food&sort=-occurred_on&filter[from]=2026-09-01&filter[to]=2026-09-30',
      );
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.query, {
        'page[number]': '2',
        'page[size]': 30,
        'filter[year]': '2026',
        'filter[month]': '9',
        'filter[day]': '1',
        'filter[category]': 'food',
        'sort': '-occurred_on',
        'filter[from]': '2026-09-01',
        'filter[to]': '2026-09-30',
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
        'page[size]': 30,
        if (limits.from != null) 'filter[from]': '2026-09-01',
        if (limits.to != null) 'filter[to]': '2026-09-30',
      });
    }
  });

  test('invalid continuations fail before HTTP without being masked', () async {
    for (final link in ['', 'expenses', '?page[number]=2#fragment']) {
      await expectLater(repository.get(pageLink: link), throwsFormatException);
    }
    verifyZeroInteractions(client);
  });

  test(
    'suggestions preserve order, optional cents and special query characters',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'data': [
              {
                'id': 'rent',
                'type': 'expense-suggestions',
                'attributes': {'description': 'Aluguel', 'amount': 160000},
              },
              {
                'id': 'market',
                'type': 'expense-suggestions',
                'attributes': {'description': 'Mercado'},
              },
            ],
          },
        ),
      );
      const query = ' [Demo] Aluguél & ?/# ';
      final result = await repository.suggestions(query: query);
      expect(result.map((item) => item.id), ['rent', 'market']);
      expect(result.map((item) => item.cents), [160000, null]);
      expect(() => result.clear(), throwsUnsupportedError);
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'expenses/suggestions');
      expect(request.query, {'query': query});
      expect(request.body, isNull);
      expect(request.headers, isNull);
    },
  );

  test(
    'empty suggestions succeed but malformed suggestions propagate',
    () async {
      when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(status: 200, body: {'data': []}),
      );
      expect(await repository.suggestions(query: 'Mer'), isEmpty);
      for (final data in [
        null,
        {},
        [
          {
            'id': 'bad',
            'attributes': {'description': 10},
          },
        ],
      ]) {
        when(
          () => client.get(parameter: any(named: 'parameter')),
        ).thenAnswer((_) async => Responses(status: 200, body: {'data': data}));
        await expectLater(
          repository.suggestions(query: 'Mer'),
          throwsA(isA<TypeError>()),
        );
      }
    },
  );

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
        'create' => repository.create(cents: 0, description: ' Original '),
        'update' => repository.update(id: '8', cents: 0),
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

    test('$operation preserves ordered HTTP errors and all metadata', () async {
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
    });

    test('$operation uses safe fallback for malformed remote errors', () async {
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
    });

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
      final result = execute().then((value) {
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
      await result;
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
              'attributes': {
                ...attributes,
                if (malformed == 'date') 'occurred_on': 'not-a-date',
                if (malformed == 'category') 'category': 'unknown',
                if (malformed == 'amount') 'amount': 0,
                if (malformed == 'fraction') 'amount': 1.5,
              },
            },
          };
          stub(
            () async => Responses(
              status: 200,
              body: operation == 'get' || operation == 'suggestions'
                  ? {
                      'data': [resource, invalid],
                      'links': {'next': null, 'prev': null},
                    }
                  : {'data': invalid},
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
      final large = {
        ...resource,
        'attributes': {...attributes, 'amount': 9007199254740993},
      };
      stub(
        () async => Responses(
          status: 200,
          body: operation == 'get' || operation == 'suggestions'
              ? {
                  'data': [large],
                  'links': {'next': null, 'prev': null},
                }
              : {'data': large},
        ),
      );
      final result = await execute();
      if (result is List<ExpenseSuggestionEntity>) {
        expect(result.single.cents, 9007199254740993);
        return;
      }
      final expense = result is ExpenseEntity
          ? result
          : (result as ExpensePageEntity).items.single;
      expect(expense.cents.cents, 9007199254740993);
    });
  }
}
