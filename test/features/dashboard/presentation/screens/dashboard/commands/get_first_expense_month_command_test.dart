import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_first_expense_month_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  late GetFirstExpenseMonthCommand command;
  void onResult() {}

  ExpenseEntity expense(DateTime date) => ExpenseEntity(
    category: .other,
    occurredOn: date,
    description: 'Gasto',
    id: date.toIso8601String(),
    cents: .create(cents: 100).right,
  );

  ExpensePageEntity page(List<DateTime> dates, {String? next}) =>
      ExpensePageEntity(
        next: next,
        prev: null,
        items: dates.map(expense).toList(),
      );

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = GetFirstExpenseMonthCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('waits for execution before querying the history', () {
    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verifyZeroInteractions(repository);
  });

  test('finds the earliest civil month across unordered pages', () async {
    const next = 'https://example.com/api/expenses?page[after]=opaque';
    when(() => repository.get()).thenAnswer(
      (_) async => Right(
        page([
          DateTime(2026, 10, 10),
          DateTime.utc(2025, 12, 31, 23),
        ], next: next),
      ),
    );
    when(() => repository.get(pageLink: next)).thenAnswer(
      (_) async => Right(page([DateTime(2025, 2, 28), DateTime(2026, 1, 1)])),
    );

    final data = await command.execute.runAsync();

    expect(data, DateTime(2025, 2));
    expect(command.execute.value, DateTime(2025, 2));
    expect(command.execute.results.value.data, DateTime(2025, 2));
    verify(() => repository.get()).called(1);
    verify(() => repository.get(pageLink: next)).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('continues through an empty page when a next link exists', () async {
    const next = '?page[after]=empty';
    when(() => repository.get())
        .thenAnswer((_) async => Right(page([], next: next)));
    when(() => repository.get(pageLink: next))
        .thenAnswer((_) async => Right(page([DateTime(2024, 9, 10)])));

    expect(await command.execute.runAsync(), DateTime(2024, 9));
  });

  test(
    'returns a successful absent month when there are no expenses',
    () async {
      when(() => repository.get()).thenAnswer((_) async => Right(page([])));

      final data = await command.execute.runAsync();

      expect(data, isNull);
      expect(command.execute.results.value.hasError, isFalse);
      expect(command.execute.results.value.isRunning, isFalse);
      verify(() => repository.get()).called(1);
    },
  );

  test(
    'preserves later page errors without publishing a partial limit',
    () async {
      const next = '?page[after]=first';
      const errors = ErrorsEntity(
        errors: [
          ErrorEntity(
            status: '422',
            pointer: '/data/id',
            parameter: 'page[after]',
            title: 'Filtro inválido',
            detail: 'Continuação inválida.',
          ),
          ErrorEntity(),
        ],
      );
      when(() => repository.get()).thenAnswer(
        (_) async => Right(page([DateTime(2026, 10, 1)], next: next)),
      );
      when(() => repository.get(pageLink: next))
          .thenAnswer((_) async => Left(errors));

      await expectLater(
        command.execute.runAsync(),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );
      expect(command.execute.value, isNull);
      expect(
        command.execute.errors.value?.error,
        same(command.execute.results.value.error),
      );
    },
  );

  test(
    'rejects repeating continuations instead of looping indefinitely',
    () async {
      const next = '?page[after]=repeated';
      when(() => repository.get())
          .thenAnswer((_) async => Right(page([], next: next)));
      when(() => repository.get(pageLink: next))
          .thenAnswer((_) async => Right(page([], next: next)));

      await expectLater(
        command.execute.runAsync(),
        throwsA(isA<CommandFailureException>()),
      );
      verify(() => repository.get(pageLink: next)).called(1);
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('replaces the limit after the first expense changes', () async {
    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2025, 1, 1)])));
    expect(await command.execute.runAsync(), DateTime(2025, 1));

    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2026, 9, 1)])));
    expect(await command.execute.runAsync(), DateTime(2026, 9));
  });

  test('keeps history limits isolated between instances', () async {
    final other = GetFirstExpenseMonthCommand(repository: repository);
    addTearDown(other.dispose);
    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2026, 9, 1)])));

    await command.execute.runAsync();

    expect(other.execute.value, isNull);
    expect(other.execute.results.value.data, isNull);
    expect(other.execute.isRunning.value, isFalse);
  });

  test('allows retry after a history query fails', () async {
    when(() => repository.get())
        .thenAnswer((_) async => Left(ErrorsEntity.unknown()));
    await expectLater(
      command.execute.runAsync(),
      throwsA(isA<CommandFailureException>()),
    );

    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2026, 9, 1)])));
    expect(await command.execute.runAsync(), DateTime(2026, 9));
  });

  test('preserves empty typed errors after a previous valid limit', () async {
    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2026, 9, 1)])));
    await command.execute.runAsync();
    const errors = ErrorsEntity(errors: []);
    when(() => repository.get()).thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );

    expect(command.execute.value, DateTime(2026, 9));
    expect(command.execute.results.value.data, isNull);
    expect(
      command.execute.errors.value?.error,
      same(command.execute.results.value.error),
    );
  });

  test(
    'preserves unexpected failures in the Future and error observables',
    () async {
      final failure = StateError('repository unavailable');
      when(() => repository.get()).thenThrow(failure);

      await expectLater(command.execute.runAsync(), throwsA(same(failure)));

      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));
    },
  );

  test(
    'does not create a late failure or another page after disposal',
    () async {
      final disposable = GetFirstExpenseMonthCommand(repository: repository);
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      when(() => repository.get()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final execution = disposable.execute.runAsync();
      await started.future;
      disposable.dispose();
      pending.complete(Left(ErrorsEntity.unknown()));

      expect(await execution, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(disposable.execute.results.value.data, isNull);
      expect(disposable.execute.results.value.hasError, isFalse);
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test(
    'blocks concurrent executions until the complete history is loaded',
    () async {
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      when(() => repository.get()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      final data = command.execute.runAsync();
      await started.future;
      expect(command.execute.isRunning.value, isTrue);
      command.execute.run();
      pending.complete(Right(page([DateTime(2026, 9, 1)])));

      expect(await data, DateTime(2026, 9));
      expect(command.execute.isRunning.value, isFalse);
      verify(() => repository.get()).called(1);
    },
  );

  test(
    'stops requesting pages when disposed during a pending request',
    () async {
      final disposable = GetFirstExpenseMonthCommand(repository: repository);
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      when(() => repository.get()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      final data = disposable.execute.runAsync();
      await started.future;
      disposable.dispose();
      pending.complete(Right(page([], next: '?page[after]=unused')));
      await data;

      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
