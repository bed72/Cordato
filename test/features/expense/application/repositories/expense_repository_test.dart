import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/application/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';

import '../../../../support/expense/mocks/expense_remote_data_source_mock.dart';

void main() {
  late CreateExpenseInput input;
  late ExpenseRepository repository;
  late ExpenseRemoteDataSourceMock dataSource;

  setUp(() {
    dataSource = ExpenseRemoteDataSourceMock();
    repository = ExpenseRepository(remoteDataSource: dataSource);
    input = CreateExpenseInput(
      cents: 300,
      description: 'Game',
      occurredOn: DateTime(2026, 10, 5),
    );
  });

  test(
    'delegates pagination and maps an immutable page in API order',
    () async {
      final responses = [
        ExpenseResponse(
          id: '9',
          amount: 301,
          description: 'Game',
          category: .leisure,
          occurredOn: DateTime(2026, 10, 7),
        ),
        ExpenseResponse(
          id: '2',
          amount: 80,
          category: .other,
          description: 'Passeio',
          occurredOn: DateTime(2026, 10, 5),
        ),
      ];
      const link = '?page[after]=10';
      when(() => dataSource.get(pageSize: 6, pageLink: link)).thenAnswer(
        (_) async => Right(
          ExpensePageResponse(
            items: responses,
            next: '?page[after]=2',
            prev: '?page[before]=9',
          ),
        ),
      );

      final page = (await repository.get(pageSize: 6, pageLink: link)).right;

      expect(page.next, '?page[after]=2');
      expect(page.prev, '?page[before]=9');
      expect(page.items.first.description, 'Game');
      expect(page.items.map((item) => item.id), ['9', '2']);
      expect(() => page.items.clear(), throwsUnsupportedError);
      expect(page.items.first.category, responses.first.category);
      expect(page.items.map((item) => item.cents.cents), [301, 80]);
      expect(page.items.first.occurredOn, responses.first.occurredOn);
      verify(() => dataSource.get(pageSize: 6, pageLink: link)).called(1);
      verifyNoMoreInteractions(dataSource);
    },
  );

  test('returns an empty page as success', () async {
    when(() => dataSource.get(pageSize: 6)).thenAnswer(
      (_) async =>
          Right(ExpensePageResponse(items: [], next: null, prev: null)),
    );

    final page = (await repository.get(pageSize: 6)).right;

    expect(page.next, isNull);
    expect(page.prev, isNull);
    expect(page.items, isEmpty);
  });

  test('requests 30 items when the page size is omitted', () async {
    final response = ExpensePageResponse(items: [], next: null, prev: null);
    when(() => dataSource.get(pageSize: 30))
        .thenAnswer((_) async => Right(response));

    final IExpenseRepository contract = repository;
    final page = (await contract.get()).right;

    expect(page.items, isEmpty);
    verify(() => dataSource.get(pageSize: 30)).called(1);
    verifyNoMoreInteractions(dataSource);
  });

  for (final size in [0, -6]) {
    test(
      'requests 30 items for page size $size and preserves continuation',
      () async {
        const link = '?page[after]=10';
        final response = ExpensePageResponse(
          items: [],
          next: '?page[after]=20',
          prev: '?page[before]=10',
        );
        when(() => dataSource.get(pageSize: 30, pageLink: link))
            .thenAnswer((_) async => Right(response));

        final page = (await repository.get(pageSize: size, pageLink: link)).right;

        expect(page.items, isEmpty);
        expect(page.next, response.next);
        expect(page.prev, response.prev);
        verify(() => dataSource.get(pageSize: 30, pageLink: link)).called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );
  }

  test('preserves positive sizes below and above the default', () async {
    for (final size in [1, 20, 60]) {
      when(() => dataSource.get(pageSize: size)).thenAnswer(
        (_) async => Right(ExpensePageResponse(items: [], next: null, prev: null)),
      );

      expect((await repository.get(pageSize: size)).right.items, isEmpty);

      verify(() => dataSource.get(pageSize: size)).called(1);
    }
    verifyNoMoreInteractions(dataSource);
  });

  test(
    'preserves listing errors and translates unexpected exceptions',
    () async {
      when(() => dataSource.get(pageSize: 6)).thenAnswer(
        (_) async => const Left(
          ErrorsResponse(
            errors: [
              ErrorResponse(
                status: '401',
                title: 'Não autorizado',
                detail: 'Sessão inválida',
              ),
            ],
          ),
        ),
      );

      final errors = (await repository.get(pageSize: 6)).left.errors;

      expect(errors.single.status, '401');
      expect(errors.single.title, 'Não autorizado');
      expect(errors.single.detail, 'Sessão inválida');
      when(() => dataSource.get(pageSize: 6)).thenThrow(StateError('failure'));
      expect(
        (await repository.get(pageSize: 6)).left.errors.single.title,
        'Erro desconhecido',
      );
      when(() => dataSource.get(pageSize: 6))
          .thenAnswer((_) async => throw StateError('failure'));

      expect((await repository.get(pageSize: 6)).isLeft, isTrue);
    },
  );

  test('fails the whole page when any expense has invalid cents', () async {
    for (final amount in [0, -1]) {
      when(() => dataSource.get(pageSize: 6)).thenAnswer(
        (_) async => Right(
          ExpensePageResponse(
            items: [
              ExpenseResponse(
                id: '9',
                amount: 300,
                category: .other,
                description: 'Game',
                occurredOn: DateTime(2026, 10, 5),
              ),
              ExpenseResponse(
                id: '2',
                amount: amount,
                category: .other,
                description: 'Inválido',
                occurredOn: DateTime(2026, 10, 5),
              ),
            ],
            next: null,
            prev: null,
          ),
        ),
      );
      expect(
        (await repository.get(pageSize: 6)).left.errors.single.title,
        'Valor inválido',
      );
    }
  });

  test(
    'delegates the input and returns the expense provided by the API',
    () async {
      final response = ExpenseResponse(
        id: '9',
        amount: 301,
        category: .leisure,
        description: 'Game atualizado',
        occurredOn: DateTime(2026, 10, 6),
      );
      when(() => dataSource.create(input: input))
          .thenAnswer((_) async => Right(response));

      final data = await repository.create(input: input);

      expect(data.right.id, '9');
      expect(data.right.cents.cents, 301);
      expect(data.right.category, response.category);
      expect(data.right.description, 'Game atualizado');
      expect(data.right.occurredOn, response.occurredOn);
      verify(() => dataSource.create(input: input)).called(1);
      verifyNoMoreInteractions(dataSource);
    },
  );

  test('preserves all remote errors and their field pointers', () async {
    const errors = ErrorsResponse(
      errors: [
        ErrorResponse(
          status: '422',
          title: 'Descrição inválida',
          detail: 'Informe uma descrição.',
          pointer: '/data/attributes/description',
        ),
        ErrorResponse(
          status: '422',
          title: 'Valor inválido',
          detail: 'Informe um valor positivo.',
          pointer: '/data/attributes/amount',
        ),
      ],
    );
    when(() => dataSource.create(input: input))
        .thenAnswer((_) async => const Left(errors));

    final data = await repository.create(input: input);

    expect(data.left.errors, hasLength(2));
    expect(data.left.errors.first.status, '422');
    expect(data.left.errors.first.title, 'Descrição inválida');
    expect(data.left.errors.first.detail, 'Informe uma descrição.');
    expect(data.left.errors.last.pointer, '/data/attributes/amount');
    expect(data.left.errors.first.pointer, '/data/attributes/description');
  });

  test('returns a generic error when the remote error list is empty', () async {
    when(() => dataSource.create(input: input))
        .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

    final data = await repository.create(input: input);

    expect(data.left.errors.single.title, 'Erro desconhecido');
  });

  for (final cents in [0, -300]) {
    test(
      'preserves the domain validation failure for $cents returned cents',
      () async {
        when(() => dataSource.create(input: input)).thenAnswer(
          (_) async => Right(
            ExpenseResponse(
              id: '9',
              amount: cents,
              description: 'Game',
              occurredOn: DateTime(2026, 10, 5),
              category: .other,
            ),
          ),
        );

        final data = await repository.create(input: input);

        expect(data.isLeft, isTrue);
        expect(data.left.errors.single.title, 'Valor inválido');
      },
    );
  }

  test(
    'translates a synchronous data source exception into a generic error',
    () async {
      when(() => dataSource.create(input: input))
          .thenThrow(StateError('failure'));

      final data = await repository.create(input: input);

      expect(data.left.errors.single.title, 'Erro desconhecido');
    },
  );

  test(
    'translates an asynchronous data source exception into a generic error',
    () async {
      when(() => dataSource.create(input: input))
          .thenAnswer((_) async => throw StateError('failure'));

      final data = await repository.create(input: input);

      expect(data.left.errors.single.title, 'Erro desconhecido');
    },
  );
}
