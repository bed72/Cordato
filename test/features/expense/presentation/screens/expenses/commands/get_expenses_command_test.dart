import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpensePageEntity page;
  late GetExpensesCommand command;
  late ExpenseRepositoryMock repository;

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = GetExpensesCommand(repository: repository);
    page = ExpensePageEntity(
      items: [
        ExpenseEntity(
          id: '15',
          category: .other,
          description: 'Lanche',
          occurredOn: DateTime(2026, 10, 8),
          cents: .create(cents: 10000).right,
        ),
      ],
      prev: null,
      next: '?page[after]=15',
    );
  });

  tearDown(() => command.dispose());

  test('waits for execution before requesting expenses', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  test(
    'delegates the requested size and publishes the first page unchanged',
    () async {
      when(() => repository.get(pageSize: 6))
          .thenAnswer((_) async => Right(page));

      final data = await command.execute.runAsync((
        from: null,
        to: null,
        pageSize: 6,
        pageLink: null,
      ));

      expect(data?.right, same(page));
      expect(command.execute.value?.right, same(page));
      verify(() => repository.get(pageSize: 6)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'delegates opaque continuations and replaces the previous page',
    () async {
      when(() => repository.get(pageSize: 6))
          .thenAnswer((_) async => Right(page));
      await command.execute.runAsync((
        pageSize: 6,
        to: null,
        from: null,
        pageLink: null,
      ));

      final continuation = ExpensePageEntity(
        items: [],
        next: null,
        prev: '?page[before]=15',
      );

      when(() => repository.get(pageSize: 20, pageLink: page.next))
          .thenAnswer((_) async => Right(continuation));

      final data = await command.execute.runAsync((
        to: null,
        from: null,
        pageSize: 20,
        pageLink: page.next,
      ));

      expect(data?.right, same(continuation));
      expect(command.execute.value?.right.items, isEmpty);
      expect(command.execute.value?.right, same(continuation));
      verify(() => repository.get(pageSize: 20, pageLink: page.next)).called(1);
    },
  );

  test('preserves domain errors for presentation feedback', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Valor inválido',
          detail: 'O valor da despesa deve ser maior que zero.',
        ),
        ErrorEntity(title: 'Falha na consulta', status: '401'),
      ],
    );
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => const Left(errors));

    final data = await command.execute.runAsync((
      to: null,
      from: null,
      pageSize: 6,
      pageLink: null,
    ));

    expect(data?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
    verify(() => repository.get(pageSize: 6)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('prevents additional queries while a request is pending', () async {
    final started = Completer<void>();
    final pending = Completer<GetRepositoryType>();
    when(() => repository.get(pageSize: 6)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final data = command.execute.runAsync((
      pageSize: 6,
      to: null,
      from: null,
      pageLink: null,
    ));
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run((
      pageSize: 20,
      pageLink: page.next,
      to: null,
      from: null,
    ));
    verify(() => repository.get(pageSize: 6)).called(1);
    pending.complete(Right(page));

    expect((await data)?.right, same(page));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after an unsuccessful query', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => Left(errors));
    expect(
      (await command.execute.runAsync((
        pageSize: 6,
        to: null,
        from: null,
        pageLink: null,
      )))?.left,
      same(errors),
    );
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => Right(page));

    expect(
      (await command.execute.runAsync((
        pageSize: 6,
        to: null,
        from: null,
        pageLink: null,
      )))?.right,
      same(page),
    );
    expect(command.execute.value?.right, same(page));
    verify(() => repository.get(pageSize: 6)).called(2);
  });

  test('keeps query state isolated between command instances', () async {
    final otherCommand = GetExpensesCommand(repository: repository);
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => Right(page));
    try {
      await command.execute.runAsync((
        pageSize: 6,
        to: null,
        from: null,
        pageLink: null,
      ));

      expect(otherCommand.execute.value, isNull);
      expect(command.execute.value?.right, same(page));
      expect(otherCommand.execute.isRunning.value, isFalse);
    } finally {
      otherCommand.dispose();
    }
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => throw failure);
    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(
        command.execute.runAsync((
          pageSize: 6,
          to: null,
          from: null,
          pageLink: null,
        )),
        throwsA(same(failure)),
      );
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });

  test('disposes the observable execution and its loading state', () async {
    final disposable = GetExpensesCommand(repository: repository);
    disposable.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    void listener() {}
    expect(
      () => disposable.execute.addListener(listener),
      throwsAssertionError,
    );
    expect(
      () => disposable.execute.isRunning.addListener(listener),
      throwsAssertionError,
    );
    verifyZeroInteractions(repository);
  });

  test(
    'delegates civil limits unchanged on first and subsequent pages',
    () async {
      final from = DateTime.utc(2026, 9, 1, 23);
      final to = DateTime(2026, 9, 30, 12);
      for (final link in [null, page.next]) {
        when(
          () =>
              repository.get(pageSize: 20, pageLink: link, from: from, to: to),
        ).thenAnswer((_) async => Right(page));

        final result = await command.execute.runAsync((
          pageSize: 20,
          pageLink: link,
          from: from,
          to: to,
        ));

        expect(result?.right, same(page));
        verify(
          () =>
              repository.get(pageSize: 20, pageLink: link, from: from, to: to),
        ).called(1);
      }
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'preserves incomplete interval errors and their filter pointer',
    () async {
      final from = DateTime(2026, 9, 1);
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(
            status: '422',
            pointer: '/filter/from',
            title: 'Intervalo inválido',
          ),
        ],
      );
      when(() => repository.get(pageSize: 6, from: from))
          .thenAnswer((_) async => const Left(errors));

      final data = await command.execute.runAsync((
        to: null,
        from: from,
        pageSize: 6,
        pageLink: null,
      ));

      expect(data?.left, same(errors));
      expect(data?.left.errors.single.pointer, '/filter/from');
      verify(() => repository.get(pageSize: 6, from: from, to: null)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
