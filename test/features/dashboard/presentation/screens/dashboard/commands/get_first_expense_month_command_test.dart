import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_first_expense_month_command.dart';

import '../../../../../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  late ExpenseRepositoryMock repository;
  late GetFirstExpenseMonthCommand command;

  ExpenseEntity expense(DateTime date) => ExpenseEntity(
    id: date.toIso8601String(),
    category: .other,
    occurredOn: date,
    description: 'Gasto',
    cents: .create(cents: 100).right,
  );

  ExpensePageEntity page(List<DateTime> dates, {String? next}) =>
      ExpensePageEntity(
        items: dates.map(expense).toList(),
        next: next,
        prev: null,
      );

  setUp(() {
    repository = ExpenseRepositoryMock();
    command = GetFirstExpenseMonthCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('waits for execution before querying the history', () {
    expect(command.execute.value, isNull);
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

    final result = await command.execute.runAsync();

    expect(result?.right, DateTime(2025, 2));
    expect(command.execute.value?.right, DateTime(2025, 2));
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

    expect((await command.execute.runAsync())?.right, DateTime(2024, 9));
  });

  test(
    'returns a successful absent month when there are no expenses',
    () async {
      when(() => repository.get()).thenAnswer((_) async => Right(page([])));

      final result = await command.execute.runAsync();

      expect(result?.isRight, isTrue);
      expect(result?.right, isNull);
    },
  );

  test(
    'preserves later page errors without publishing a partial limit',
    () async {
      const next = '?page[after]=first';
      final errors = ErrorsEntity.unknown();
      when(() => repository.get()).thenAnswer(
        (_) async => Right(page([DateTime(2026, 10, 1)], next: next)),
      );
      when(() => repository.get(pageLink: next))
          .thenAnswer((_) async => Left(errors));

      expect((await command.execute.runAsync())?.left, same(errors));
      expect(command.execute.value?.left, same(errors));
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

      expect((await command.execute.runAsync())?.isLeft, isTrue);
      verify(() => repository.get(pageLink: next)).called(1);
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('replaces the limit after the first expense changes', () async {
    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2025, 1, 1)])));
    expect((await command.execute.runAsync())?.right, DateTime(2025, 1));

    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2026, 9, 1)])));
    expect((await command.execute.runAsync())?.right, DateTime(2026, 9));
  });

  test('allows retry after a history query fails', () async {
    when(() => repository.get())
        .thenAnswer((_) async => Left(ErrorsEntity.unknown()));
    expect((await command.execute.runAsync())?.isLeft, isTrue);

    when(() => repository.get())
        .thenAnswer((_) async => Right(page([DateTime(2026, 9, 1)])));
    expect((await command.execute.runAsync())?.right, DateTime(2026, 9));
  });

  test(
    'blocks concurrent executions until the complete history is loaded',
    () async {
      final started = Completer<void>();
      final pending = Completer<GetRepositoryType>();
      when(() => repository.get()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });

      final result = command.execute.runAsync();
      await started.future;
      expect(command.execute.isRunning.value, isTrue);
      command.execute.run();
      pending.complete(Right(page([DateTime(2026, 9, 1)])));

      expect((await result)?.right, DateTime(2026, 9));
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

      final result = disposable.execute.runAsync();
      await started.future;
      disposable.dispose();
      pending.complete(Right(page([], next: '?page[after]=unused')));
      await result;

      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
