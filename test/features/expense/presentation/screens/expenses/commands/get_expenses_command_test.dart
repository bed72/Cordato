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
        category: null,
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
        category: null,
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
        category: null,
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
      category: null,
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
      category: null,
    ));
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run((
      pageSize: 20,
      pageLink: page.next,
      to: null,
      from: null,
      category: null,
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
        category: null,
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
        category: null,
      )))?.right,
      same(page),
    );
    expect(command.execute.value?.right, same(page));
    verify(() => repository.get(pageSize: 6)).called(2);
  });

  for (final outcome in ['right', 'left', 'exception']) {
    test('publishes terminal $outcome before releasing execution', () async {
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      final idle = Completer<void>();
      final failure = StateError('repository unavailable');
      final errors = ErrorsEntity.unknown();
      final events = <String>[];
      bool? runningAtResult;
      GetRepositoryType? valueAtResult;
      GetRepositoryType? terminalData;
      Object? terminalError;

      when(() => repository.get(pageSize: 6)).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      void onResult() {
        final result = command.execute.results.value;
        if (result.isRunning) return;
        events.add('result');
        runningAtResult = command.execute.isRunning.value;
        valueAtResult = command.execute.value;
        terminalData = result.data;
        terminalError = result.error;
      }

      void onValue() => events.add('value');

      void onExecution() {
        if (command.execute.isRunning.value) return;
        events.add('idle');
        idle.complete();
      }

      command.execute.results.addListener(onResult);
      command.execute.addListener(onValue);
      command.execute.isRunning.addListener(onExecution);
      try {
        final execution = command.execute.runAsync((
          pageSize: 6,
          pageLink: null,
          from: null,
          to: null,
          category: null,
        ));
        final conclusion = outcome == 'exception'
            ? expectLater(execution, throwsA(same(failure)))
            : execution;
        await started.future;

        switch (outcome) {
          case 'right':
            pending.complete(Right(page));
          case 'left':
            pending.complete(Left(errors));
          case 'exception':
            pending.completeError(failure);
        }

        await conclusion;
        await idle.future;

        expect(runningAtResult, isTrue);
        expect(valueAtResult, isNull);
        expect(
          events,
          outcome == 'exception'
              ? ['result', 'idle']
              : ['result', 'value', 'idle'],
        );
        switch (outcome) {
          case 'right':
            expect(terminalData?.right, same(page));
            expect(terminalError, isNull);
          case 'left':
            expect(terminalData?.left, same(errors));
            expect(terminalError, isNull);
          case 'exception':
            expect(terminalData, isNull);
            expect(terminalError, same(failure));
        }
      } finally {
        command.execute.results.removeListener(onResult);
        command.execute.removeListener(onValue);
        command.execute.isRunning.removeListener(onExecution);
      }
    });
  }

  test(
    'starts a fresh query from a microtask after execution becomes idle',
    () async {
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      final refreshed = Completer<GetRepositoryType?>();
      bool refreshPending = true;
      when(() => repository.get(pageSize: 6)).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final nextPage = ExpensePageEntity(items: [], next: null, prev: null);
      when(() => repository.get(pageSize: 20))
          .thenAnswer((_) async => Right(nextPage));

      void onExecution() {
        if (command.execute.isRunning.value || !refreshPending) return;
        refreshPending = false;
        Future<void>.microtask(() async {
          try {
            refreshed.complete(
              await command.execute.runAsync((
                pageSize: 20,
                pageLink: null,
                from: null,
                to: null,
                category: null,
              )),
            );
          } catch (error, stackTrace) {
            refreshed.completeError(error, stackTrace);
          }
        });
      }

      command.execute.isRunning.addListener(onExecution);
      try {
        final first = command.execute.runAsync((
          pageSize: 6,
          pageLink: null,
          from: null,
          to: null,
          category: null,
        ));
        await started.future;
        pending.complete(Right(page));

        expect((await first)?.right, same(page));
        expect((await refreshed.future)?.right, same(nextPage));
        verify(() => repository.get(pageSize: 6)).called(1);
        verify(() => repository.get(pageSize: 20)).called(1);
        verifyNoMoreInteractions(repository);
      } finally {
        command.execute.isRunning.removeListener(onExecution);
      }
    },
  );

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
        category: null,
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
          category: null,
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
          () => repository.get(
            pageSize: 20,
            pageLink: link,
            from: from,
            to: to,
            category: 'food',
          ),
        ).thenAnswer((_) async => Right(page));

        final result = await command.execute.runAsync((
          pageSize: 20,
          pageLink: link,
          from: from,
          to: to,
          category: 'food',
        ));

        expect(result?.right, same(page));
        verify(
          () => repository.get(
            pageSize: 20,
            pageLink: link,
            from: from,
            to: to,
            category: 'food',
          ),
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
        category: null,
      ));

      expect(data?.left, same(errors));
      expect(data?.left.errors.single.pointer, '/filter/from');
      verify(() => repository.get(pageSize: 6, from: from, to: null)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
