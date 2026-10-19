import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/expense/infrastructure/responses/expense_response.dart';
import 'package:cordato/features/expense/application/repositories/expense_repository.dart';
import 'package:cordato/features/expense/infrastructure/responses/expense_page_response.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import '../../../../support/expense/mocks/expense_remote_data_source_mock.dart';

void main() {
  late DateTime occurredOn;
  late ExpenseRepository repository;
  late ExpenseRemoteDataSourceMock dataSource;

  setUp(() {
    occurredOn = DateTime(2026, 10, 5);
    dataSource = ExpenseRemoteDataSourceMock();
    repository = ExpenseRepository(remoteDataSource: dataSource);
  });

  test('delegates ascending sorting and a single item without changing other readers', () async {
    when(() => dataSource.get(pageSize: 1, sort: 'occurred_on')).thenAnswer(
      (_) async => Right(
        ExpensePageResponse(items: [], next: '?page[cursor]=next', prev: null),
      ),
    );
    final result = await repository.get(pageSize: 1, sort: 'occurred_on');
    expect(result.right.items, isEmpty);
    expect(result.right.next, '?page[cursor]=next');
    verify(() => dataSource.get(pageSize: 1, sort: 'occurred_on')).called(1);
    verifyNoMoreInteractions(dataSource);
  });

  group('getById', () {
    test(
      'delegates the unchanged id and maps the resource returned by the API',
      () async {
        final response = ExpenseResponse(
          id: '9',
          amount: 1500,
          category: .transport,
          occurredOn: occurredOn,
          description: 'Ônibus e metrô',
        );
        when(() => dataSource.getById(id: 'a/b?c#d'))
            .thenAnswer((_) async => Right(response));
        final IExpenseRepository contract = repository;
        final expense = (await contract.getById(id: 'a/b?c#d')).right;

        expect(expense.id, response.id);
        expect(expense.category, response.category);
        expect(expense.cents.cents, response.amount);
        expect(expense.occurredOn, response.occurredOn);
        expect(expense.description, response.description);
        verify(() => dataSource.getById(id: 'a/b?c#d')).called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );
    test('preserves remote errors and their metadata', () async {
      when(() => dataSource.getById(id: '8')).thenAnswer(
        (_) async => const Left(
          ErrorsResponse(
            errors: [
              ErrorResponse(
                status: '404',
                pointer: '/data/id',
                title: 'Despesa não encontrada',
                detail: 'A despesa não existe.',
              ),
              ErrorResponse(title: 'Outro erro', status: '404'),
            ],
          ),
        ),
      );
      final errors = (await repository.getById(id: '8')).left.errors;
      expect(errors, hasLength(2));
      expect(errors.first.status, '404');
      expect(errors.last.title, 'Outro erro');
      expect(errors.first.pointer, '/data/id');
      expect(errors.first.title, 'Despesa não encontrada');
      expect(errors.first.detail, 'A despesa não existe.');
    });
    test('returns a generic error for an empty remote error list', () async {
      when(() => dataSource.getById(id: '8'))
          .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));
      expect(
        (await repository.getById(id: '8')).left.errors.single.title,
        'Erro desconhecido',
      );
    });
    for (final amount in [0, -1]) {
      test('rejects $amount cents in the fetched resource', () async {
        when(() => dataSource.getById(id: '8')).thenAnswer(
          (_) async => Right(
            ExpenseResponse(
              id: '8',
              amount: amount,
              category: .other,
              description: 'Game',
              occurredOn: occurredOn,
            ),
          ),
        );
        expect(
          (await repository.getById(id: '8')).left.errors.single.title,
          'Valor inválido',
        );
      });
    }
    test(
      'translates synchronous and asynchronous data source exceptions',
      () async {
        when(() => dataSource.getById(id: '8'))
            .thenThrow(StateError('failure'));
        expect(
          (await repository.getById(id: '8')).left.errors.single.title,
          'Erro desconhecido',
        );
        when(() => dataSource.getById(id: '8'))
            .thenAnswer((_) async => throw StateError('failure'));
        expect(
          (await repository.getById(id: '8')).left.errors.single.title,
          'Erro desconhecido',
        );
      },
    );
  });

  group('update', () {
    test(
      'delegates unchanged parameters and maps the expense returned by the API',
      () async {
        const id = 'a/b?c#d';
        final updatedDate = DateTime.utc(2026, 10, 7, 23, 30);
        final response = ExpenseResponse(
          id: '9',
          amount: 1600,
          category: .transport,
          occurredOn: DateTime(2026, 10, 6),
          description: 'Ônibus e metrô atualizado',
        );
        when(
          () => dataSource.update(
            id: id,
            cents: 1500,
            occurredOn: updatedDate,
            description: ' Ônibus e metrô ',
          ),
        ).thenAnswer((_) async => Right(response));
        final IExpenseRepository contract = repository;

        final expense = (await contract.update(
          id: id,
          cents: 1500,
          occurredOn: updatedDate,
          description: ' Ônibus e metrô ',
        )).right;

        expect(expense.id, response.id);
        expect(expense.category, response.category);
        expect(expense.cents.cents, response.amount);
        expect(expense.occurredOn, response.occurredOn);
        expect(expense.description, response.description);
        verify(
          () => dataSource.update(
            id: id,
            cents: 1500,
            occurredOn: updatedDate,
            description: ' Ônibus e metrô ',
          ),
        ).called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );

    test(
      'delegates partial updates and omitted attributes without defaults',
      () async {
        final response = ExpenseResponse(
          id: '8',
          amount: 1500,
          description: 'Ônibus e metrô',
          occurredOn: occurredOn,
          category: .other,
        );
        for (final parameters in [
          (cents: 1500, description: null, occurredOn: null),
          (cents: null, description: 'Ônibus e metrô', occurredOn: null),
          (cents: null, description: null, occurredOn: null),
          (cents: 0, description: '', occurredOn: null),
          (cents: -1, description: ' ', occurredOn: null),
          (cents: null, description: null, occurredOn: DateTime(2026, 10, 7)),
        ]) {
          when(
            () => dataSource.update(
              id: '8',
              cents: parameters.cents,
              occurredOn: parameters.occurredOn,
              description: parameters.description,
            ),
          ).thenAnswer((_) async => Right(response));

          final data = await repository.update(
            id: '8',
            cents: parameters.cents,
            occurredOn: parameters.occurredOn,
            description: parameters.description,
          );

          expect(data.right.cents.cents, 1500);
          verify(
            () => dataSource.update(
              id: '8',
              cents: parameters.cents,
              occurredOn: parameters.occurredOn,
              description: parameters.description,
            ),
          ).called(1);
        }
        expect((await repository.update(id: '8')).isRight, isTrue);
        verify(() => dataSource.update(id: '8', cents: null, description: null))
            .called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );

    test('preserves every remote validation error and field pointer', () async {
      when(() => dataSource.update(id: '8', cents: 0, description: ''))
          .thenAnswer(
            (_) async => const Left(
              ErrorsResponse(
                errors: [
                  ErrorResponse(
                    status: '422',
                    title: 'Valor inválido',
                    pointer: '/data/attributes/amount',
                    detail: 'Informe um valor positivo.',
                  ),
                  ErrorResponse(
                    status: '422',
                    title: 'Descrição inválida',
                    detail: 'Informe uma descrição.',
                    pointer: '/data/attributes/description',
                  ),
                ],
              ),
            ),
          );

      final errors = (await repository.update(
        id: '8',
        cents: 0,
        description: '',
      )).left.errors;

      expect(errors, hasLength(2));
      expect(errors.last.status, '422');
      expect(errors.first.status, '422');
      expect(errors.first.title, 'Valor inválido');
      expect(errors.last.title, 'Descrição inválida');
      expect(errors.last.detail, 'Informe uma descrição.');
      expect(errors.first.pointer, '/data/attributes/amount');
      expect(errors.first.detail, 'Informe um valor positivo.');
      expect(errors.last.pointer, '/data/attributes/description');
      verify(() => dataSource.update(id: '8', cents: 0, description: ''))
          .called(1);
      verifyNoMoreInteractions(dataSource);
    });

    test(
      'preserves authentication, authorization, not found and transport errors',
      () async {
        for (final status in ['401', '403', '404', '0']) {
          when(() => dataSource.update(id: '8')).thenAnswer(
            (_) async => Left(
              ErrorsResponse(
                errors: [
                  ErrorResponse(
                    status: status,
                    title: 'Falha na edição',
                    detail: 'Tente novamente.',
                  ),
                ],
              ),
            ),
          );

          final error = (await repository.update(id: '8')).left.errors.single;

          expect(error.status, status);
          expect(error.title, 'Falha na edição');
          expect(error.detail, 'Tente novamente.');
          verify(() => dataSource.update(id: '8')).called(1);
        }
        verifyNoMoreInteractions(dataSource);
      },
    );

    test('returns a generic error for an empty remote error list', () async {
      when(() => dataSource.update(id: '8'))
          .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

      expect(
        (await repository.update(id: '8')).left.errors.single.title,
        'Erro desconhecido',
      );
    });

    for (final amount in [0, -1500]) {
      test(
        'preserves domain validation failure for $amount returned cents',
        () async {
          when(() => dataSource.update(id: '8', cents: 1500)).thenAnswer(
            (_) async => Right(
              ExpenseResponse(
                id: '8',
                amount: amount,
                description: 'Ônibus e metrô',
                occurredOn: occurredOn,
                category: .other,
              ),
            ),
          );

          final data = await repository.update(id: '8', cents: 1500);

          expect(data.isLeft, isTrue);
          expect(data.left.errors.single.title, 'Valor inválido');
          verify(() => dataSource.update(id: '8', cents: 1500)).called(1);
          verifyNoMoreInteractions(dataSource);
        },
      );
    }

    test(
      'translates synchronous data source exceptions into a generic error',
      () async {
        when(() => dataSource.update(id: '8')).thenThrow(StateError('failure'));

        expect(
          (await repository.update(id: '8')).left.errors.single.title,
          'Erro desconhecido',
        );
      },
    );

    test(
      'translates asynchronous data source exceptions into a generic error',
      () async {
        when(() => dataSource.update(id: '8'))
            .thenAnswer((_) async => throw StateError('failure'));

        expect(
          (await repository.update(id: '8')).left.errors.single.title,
          'Erro desconhecido',
        );
      },
    );
  });

  for (final deleted in [true, false]) {
    test(
      'delegates the expense id and preserves deletion data $deleted',
      () async {
        const id = 'a/b?c#d';
        when(() => dataSource.delete(id: id))
            .thenAnswer((_) async => Right(deleted));
        final IExpenseRepository contract = repository;

        final data = await contract.delete(id: id);

        expect(data.right, deleted);
        verify(() => dataSource.delete(id: id)).called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );
  }

  test('preserves all deletion error details as domain errors', () async {
    when(() => dataSource.delete(id: '1')).thenAnswer(
      (_) async => const Left(
        ErrorsResponse(
          errors: [
            ErrorResponse(
              status: '403',
              pointer: '/data/id',
              title: 'Acesso negado',
              detail: 'Sem permissão para excluir a despesa.',
            ),
            ErrorResponse(status: '403', title: 'Outro erro'),
          ],
        ),
      ),
    );

    final errors = (await repository.delete(id: '1')).left.errors;

    expect(errors, hasLength(2));
    expect(errors.last.status, '403');
    expect(errors.first.status, '403');
    expect(errors.last.title, 'Outro erro');
    expect(errors.first.pointer, '/data/id');
    expect(errors.first.title, 'Acesso negado');
    expect(errors.first.detail, 'Sem permissão para excluir a despesa.');
    verify(() => dataSource.delete(id: '1')).called(1);
    verifyNoMoreInteractions(dataSource);
  });

  test('returns a generic error for an empty deletion error list', () async {
    when(() => dataSource.delete(id: '1'))
        .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

    expect(
      (await repository.delete(id: '1')).left.errors.single.title,
      'Erro desconhecido',
    );
  });

  test(
    'translates synchronous deletion exceptions into a generic error',
    () async {
      when(() => dataSource.delete(id: '1')).thenThrow(StateError('failure'));

      expect(
        (await repository.delete(id: '1')).left.errors.single.title,
        'Erro desconhecido',
      );
    },
  );

  test(
    'translates asynchronous deletion exceptions into a generic error',
    () async {
      when(() => dataSource.delete(id: '1'))
          .thenAnswer((_) async => throw StateError('failure'));

      expect(
        (await repository.delete(id: '1')).left.errors.single.title,
        'Erro desconhecido',
      );
    },
  );

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

  test('delegates category and month unchanged across pages', () async {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 30);
    for (final link in [null, '?page[after]=opaque']) {
      when(
        () => dataSource.get(
          to: to,
          from: from,
          pageSize: 20,
          pageLink: link,
          category: 'food',
        ),
      ).thenAnswer(
        (_) async =>
            Right(ExpensePageResponse(items: [], next: null, prev: null)),
      );

      final data = await repository.get(
        to: to,
        from: from,
        pageSize: 20,
        pageLink: link,
        category: 'food',
      );

      expect(data.right.items, isEmpty);
      verify(
        () => dataSource.get(
          to: to,
          from: from,
          pageSize: 20,
          pageLink: link,
          category: 'food',
        ),
      ).called(1);
    }
    verifyNoMoreInteractions(dataSource);
  });

  test(
    'delegates complete and incomplete intervals without defaults',
    () async {
      final from = DateTime.utc(2026, 9, 1, 23);
      final to = DateTime(2026, 9, 30, 12);
      const link = '?page[after]=opaque';
      for (final limits in [
        (from: from, to: to),
        (from: from, to: null),
        (from: null, to: to),
      ]) {
        when(
          () => dataSource.get(
            pageSize: 30,
            pageLink: link,
            from: limits.from,
            to: limits.to,
          ),
        ).thenAnswer(
          (_) async =>
              Right(ExpensePageResponse(items: [], next: null, prev: link)),
        );

        final data = await repository.get(
          pageSize: 0,
          pageLink: link,
          from: limits.from,
          to: limits.to,
        );

        expect(data.right.items, isEmpty);
        expect(data.right.prev, link);
        verify(
          () => dataSource.get(
            pageSize: 30,
            pageLink: link,
            from: limits.from,
            to: limits.to,
          ),
        ).called(1);
      }
      verifyNoMoreInteractions(dataSource);
    },
  );

  test('preserves remote filter pointers for an incomplete interval', () async {
    final from = DateTime(2026, 9, 1);
    const errors = ErrorsResponse(
      errors: [
        ErrorResponse(
          status: '422',
          title: 'Intervalo inválido',
          detail: 'Informe os dois limites.',
          pointer: '/filter/from',
        ),
      ],
    );
    when(() => dataSource.get(pageSize: 6, from: from))
        .thenAnswer((_) async => const Left(errors));

    final data = await repository.get(pageSize: 6, from: from);

    expect(data.left.errors.single.pointer, '/filter/from');
    expect(data.left.errors.single.status, '422');
    expect(data.left.errors.single.detail, 'Informe os dois limites.');
    verify(() => dataSource.get(pageSize: 6, from: from, to: null)).called(1);
    verifyNoMoreInteractions(dataSource);
  });

  test('requests 30 items when the page size is omitted', () async {
    final response = ExpensePageResponse(items: [], next: null, prev: null);
    when(() => dataSource.get(pageSize: 30))
        .thenAnswer((_) async => Right(response));

    final contract = repository;
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

        final page = (await repository.get(
          pageSize: size,
          pageLink: link,
        )).right;

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
        (_) async =>
            Right(ExpensePageResponse(items: [], next: null, prev: null)),
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
    final from = DateTime(2026, 10, 1);
    final to = DateTime(2026, 10, 31);
    for (final amount in [0, -1]) {
      when(() => dataSource.get(pageSize: 6, from: from, to: to)).thenAnswer(
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
        (await repository.get(
          pageSize: 6,
          from: from,
          to: to,
        )).left.errors.single.title,
        'Valor inválido',
      );
    }
  });

  test(
    'delegates creation parameters and returns the expense provided by the API',
    () async {
      final response = ExpenseResponse(
        id: '9',
        amount: 301,
        category: .leisure,
        description: 'Game atualizado',
        occurredOn: DateTime(2026, 10, 6),
      );
      when(
        () => dataSource.create(
          cents: 300,
          description: 'Game',
          occurredOn: occurredOn,
        ),
      ).thenAnswer((_) async => Right(response));

      final data = await repository.create(
        cents: 300,
        description: 'Game',
        occurredOn: occurredOn,
      );

      expect(data.right.id, '9');
      expect(data.right.cents.cents, 301);
      expect(data.right.category, response.category);
      expect(data.right.description, 'Game atualizado');
      expect(data.right.occurredOn, response.occurredOn);
      verify(
        () => dataSource.create(
          cents: 300,
          description: 'Game',
          occurredOn: occurredOn,
        ),
      ).called(1);
      verifyNoMoreInteractions(dataSource);
    },
  );

  test(
    'delegates omitted and null creation dates without normalizing values',
    () async {
      final response = ExpenseResponse(
        id: '9',
        amount: 300,
        description: 'Game',
        category: .other,
        occurredOn: occurredOn,
      );
      when(
        () => dataSource.create(
          cents: 300,
          description: ' Game ',
          occurredOn: null,
        ),
      ).thenAnswer((_) async => Right(response));
      final IExpenseRepository contract = repository;

      expect(
        (await contract.create(cents: 300, description: ' Game ')).isRight,
        isTrue,
      );
      expect(
        (await contract.create(
          cents: 300,
          description: ' Game ',
          occurredOn: null,
        )).isRight,
        isTrue,
      );

      verify(
        () => dataSource.create(
          cents: 300,
          description: ' Game ',
          occurredOn: null,
        ),
      ).called(2);
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
    when(
      () => dataSource.create(
        cents: 300,
        description: 'Game',
        occurredOn: occurredOn,
      ),
    ).thenAnswer((_) async => const Left(errors));

    final data = await repository.create(
      cents: 300,
      description: 'Game',
      occurredOn: occurredOn,
    );

    expect(data.left.errors, hasLength(2));
    expect(data.left.errors.first.status, '422');
    expect(data.left.errors.first.title, 'Descrição inválida');
    expect(data.left.errors.first.detail, 'Informe uma descrição.');
    expect(data.left.errors.last.pointer, '/data/attributes/amount');
    expect(data.left.errors.first.pointer, '/data/attributes/description');
  });

  test('returns a generic error when the remote error list is empty', () async {
    when(
      () => dataSource.create(
        cents: 300,
        description: 'Game',
        occurredOn: occurredOn,
      ),
    ).thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

    final data = await repository.create(
      cents: 300,
      description: 'Game',
      occurredOn: occurredOn,
    );

    expect(data.left.errors.single.title, 'Erro desconhecido');
  });

  for (final cents in [0, -300]) {
    test(
      'preserves the domain validation failure for $cents returned cents',
      () async {
        when(
          () => dataSource.create(
            cents: 300,
            description: 'Game',
            occurredOn: occurredOn,
          ),
        ).thenAnswer(
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

        final data = await repository.create(
          cents: 300,
          description: 'Game',
          occurredOn: occurredOn,
        );

        expect(data.isLeft, isTrue);
        expect(data.left.errors.single.title, 'Valor inválido');
      },
    );
  }

  test(
    'translates a synchronous data source exception into a generic error',
    () async {
      when(
        () => dataSource.create(
          cents: 300,
          description: 'Game',
          occurredOn: occurredOn,
        ),
      ).thenThrow(StateError('failure'));

      final data = await repository.create(
        cents: 300,
        description: 'Game',
        occurredOn: occurredOn,
      );

      expect(data.left.errors.single.title, 'Erro desconhecido');
    },
  );

  test(
    'translates an asynchronous data source exception into a generic error',
    () async {
      when(
        () => dataSource.create(
          cents: 300,
          description: 'Game',
          occurredOn: occurredOn,
        ),
      ).thenAnswer((_) async => throw StateError('failure'));

      final data = await repository.create(
        cents: 300,
        description: 'Game',
        occurredOn: occurredOn,
      );

      expect(data.left.errors.single.title, 'Erro desconhecido');
    },
  );
}
