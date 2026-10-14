import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpensePageEntity page;
  late GetExpensesCommand command;
  late ExpenseRepositoryMock repository;
  void onResult() {}

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = GetExpensesCommand(repository: repository);
    command.execute.results.addListener(onResult);
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

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

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

      expect(data, same(page));
      expect(command.execute.value, same(page));
      expect(command.execute.results.value.data, same(page));
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

      expect(data, same(continuation));
      expect(command.execute.value?.items, isEmpty);
      expect(command.execute.value, same(continuation));
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

    await expectLater(
      command.execute.runAsync((
        to: null,
        from: null,
        pageSize: 6,
        pageLink: null,
        category: null,
      )),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );

    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isTrue);
    expect(
      (command.execute.results.value.error as CommandFailureException).errors,
      same(errors),
    );
    expect(
      command.execute.errors.value?.error,
      same(command.execute.results.value.error),
    );
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
      to: null,
      from: null,
      pageSize: 6,
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
    final joined = command.execute.runAsync((
      pageSize: 20,
      pageLink: page.next,
      to: null,
      from: null,
      category: 'food',
    ));
    expect(joined, same(data));
    verify(() => repository.get(pageSize: 6)).called(1);
    pending.complete(Right(page));

    expect(await data, same(page));
    expect(await joined, same(page));
    expect(command.execute.isRunning.value, isFalse);
    expect(command.execute.results.value.paramData?.pageSize, 6);
    expect(command.execute.results.value.paramData?.category, isNull);
    verifyNoMoreInteractions(repository);
  });

  test('allows retry after an unsuccessful query', () async {
    final errors = ErrorsEntity.unknown();
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => Left(errors));
    await expectLater(
      command.execute.runAsync((
        pageSize: 6,
        to: null,
        from: null,
        pageLink: null,
        category: null,
      )),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
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
      ))),
      same(page),
    );
    expect(command.execute.value, same(page));
    verify(() => repository.get(pageSize: 6)).called(2);
  });

  for (final outcome in ['right', 'left', 'exception']) {
    test('publishes terminal $outcome before releasing execution', () async {
      final events = <String>[];
      final idle = Completer<void>();
      final started = Completer<void>();
      final errors = ErrorsEntity.unknown();
      final pending = Completer<GetRepositoryType>();
      final failure = StateError('repository unavailable');

      bool? runningAtResult;
      Object? terminalError;
      ExpensePageEntity? valueAtResult;
      ExpensePageEntity? terminalData;

      when(() => repository.get(pageSize: 6)).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      void onResult() {
        final data = command.execute.results.value;
        if (data.isRunning) return;
        events.add('result');
        runningAtResult = command.execute.isRunning.value;
        valueAtResult = command.execute.value;
        terminalData = data.data;
        terminalError = data.error;
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
          to: null,
          from: null,
          pageSize: 6,
          pageLink: null,
          category: null,
        ));

        final conclusion = outcome == 'exception'
            ? expectLater(execution, throwsA(same(failure)))
            : outcome == 'left'
            ? expectLater(
                execution,
                throwsA(
                  isA<CommandFailureException>().having(
                    (failure) => failure.errors,
                    'errors',
                    same(errors),
                  ),
                ),
              )
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

        expect(valueAtResult, isNull);
        expect(runningAtResult, isTrue);
        expect(
          events,
          outcome != 'right' ? ['result', 'idle'] : ['result', 'value', 'idle'],
        );
        switch (outcome) {
          case 'right':
            expect(terminalData, same(page));
            expect(terminalError, isNull);
          case 'left':
            expect(terminalData, isNull);
            expect(
              (terminalError as CommandFailureException).errors,
              same(errors),
            );
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
      bool refreshPending = true;
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      final refreshed = Completer<ExpensePageEntity?>();

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
                from: null,
                to: null,
                pageSize: 20,
                pageLink: null,
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
          to: null,
          from: null,
          pageSize: 6,
          pageLink: null,
          category: null,
        ));
        await started.future;
        pending.complete(Right(page));

        expect(await first, same(page));
        expect(await refreshed.future, same(nextPage));
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
        to: null,
        from: null,
        pageSize: 6,
        pageLink: null,
        category: null,
      ));

      expect(command.execute.value, same(page));
      expect(otherCommand.execute.value, isNull);
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
          to: null,
          from: null,
          pageSize: 6,
          pageLink: null,
          category: null,
        )),
        throwsA(same(failure)),
      );
      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));
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

  test('keeps the previous page out of a failed current snapshot', () async {
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => Right(page));
    const input = (
      to: null,
      from: null,
      pageSize: 6,
      pageLink: null,
      category: null,
    );
    await command.execute.runAsync(input);
    const errors = ErrorsEntity(errors: []);
    when(() => repository.get(pageSize: 6))
        .thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(input),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );

    expect(command.execute.value, same(page));
    expect(command.execute.results.value.data, isNull);
    expect(command.execute.results.value.hasError, isTrue);
    expect(
      command.execute.errors.value?.error,
      same(command.execute.results.value.error),
    );
  });

  test('does not publish a new page when disposed during a query', () async {
    final started = Completer<void>();
    final pending = Completer<GetRepositoryType>();
    final disposable = GetExpensesCommand(repository: repository);

    when(() => repository.get(pageSize: 6)).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final execution = disposable.execute.runAsync((
      to: null,
      from: null,
      pageSize: 6,
      pageLink: null,
      category: null,
    ));

    await started.future;
    disposable.dispose();
    pending.complete(Right(page));

    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.value, isNull);
    expect(disposable.execute.results.value.data, isNull);
    verify(() => repository.get(pageSize: 6)).called(1);
  });

  test(
    'delegates civil limits unchanged on first and subsequent pages',
    () async {
      final to = DateTime(2026, 9, 30, 12);
      final from = DateTime.utc(2026, 9, 1, 23);

      for (final link in [null, page.next]) {
        when(
          () => repository.get(
            to: to,
            from: from,
            pageSize: 20,
            pageLink: link,
            category: 'food',
          ),
        ).thenAnswer((_) async => Right(page));

        final data = await command.execute.runAsync((
          to: to,
          from: from,
          pageSize: 20,
          pageLink: link,
          category: 'food',
        ));

        expect(data, same(page));
        verify(
          () => repository.get(
            to: to,
            from: from,
            pageSize: 20,
            pageLink: link,
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

      await expectLater(
        command.execute.runAsync((
          to: null,
          from: from,
          pageSize: 6,
          pageLink: null,
          category: null,
        )),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );

      final failure =
          command.execute.results.value.error as CommandFailureException;

      expect(failure.errors.errors.single.pointer, '/filter/from');
      verify(() => repository.get(pageSize: 6, from: from, to: null)).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
