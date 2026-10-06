import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/data/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';

import '../../../../support/expense/mocks/expense_remote_data_source_mock.dart';

void main() {
  late ExpenseRemoteDataSourceMock dataSource;
  late ExpenseRepository repository;
  late CreateExpenseInput input;

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
    'delegates the input and returns the expense provided by the API',
    () async {
      final response = ExpenseResponse(
        id: '9',
        amount: 301,
        description: 'Game atualizado',
        occurredOn: DateTime(2026, 10, 6),
        category: .leisure,
      );
      when(() => dataSource.create(input: input))
          .thenAnswer((_) async => Right(response));

      final result = await repository.create(input: input);

      expect(result.right.id, '9');
      expect(result.right.cents.cents, 301);
      expect(result.right.description, 'Game atualizado');
      expect(result.right.occurredOn, response.occurredOn);
      expect(result.right.category, response.category);
      verify(() => dataSource.create(input: input)).called(1);
      verifyNoMoreInteractions(dataSource);
    },
  );

  test('preserves all remote errors and their field pointers', () async {
    const errors = ErrorsResponse(
      errors: [
        ErrorResponse(
          title: 'Descrição inválida',
          detail: 'Informe uma descrição.',
          status: '422',
          pointer: '/data/attributes/description',
        ),
        ErrorResponse(
          title: 'Valor inválido',
          detail: 'Informe um valor positivo.',
          status: '422',
          pointer: '/data/attributes/amount',
        ),
      ],
    );
    when(() => dataSource.create(input: input))
        .thenAnswer((_) async => const Left(errors));

    final result = await repository.create(input: input);

    expect(result.left.errors, hasLength(2));
    expect(result.left.errors.first.title, 'Descrição inválida');
    expect(result.left.errors.first.detail, 'Informe uma descrição.');
    expect(result.left.errors.first.status, '422');
    expect(result.left.errors.first.pointer, '/data/attributes/description');
    expect(result.left.errors.last.pointer, '/data/attributes/amount');
  });

  test('returns a generic error when the remote error list is empty', () async {
    when(() => dataSource.create(input: input))
        .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

    final result = await repository.create(input: input);

    expect(result.left.errors.single.title, 'Erro desconhecido');
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

        final result = await repository.create(input: input);

        expect(result.isLeft, isTrue);
        expect(result.left.errors.single.title, 'Valor inválido');
      },
    );
  }

  test(
    'translates a synchronous data source exception into a generic error',
    () async {
      when(() => dataSource.create(input: input))
          .thenThrow(StateError('failure'));

      final result = await repository.create(input: input);

      expect(result.left.errors.single.title, 'Erro desconhecido');
    },
  );

  test(
    'translates an asynchronous data source exception into a generic error',
    () async {
      when(() => dataSource.create(input: input))
          .thenAnswer((_) async => throw StateError('failure'));

      final result = await repository.create(input: input);

      expect(result.left.errors.single.title, 'Erro desconhecido');
    },
  );
}
