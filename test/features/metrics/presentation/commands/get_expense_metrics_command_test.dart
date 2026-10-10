import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';

import '../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  const defaultFilters = (startDate: null, endDate: null, groupBy: null);
  late MetricsRepositoryMock repository;
  late GetExpenseMetricsCommand command;
  late ExpenseMetricsEntity metrics;

  setUp(() {
    repository = MetricsRepositoryMock();
    command = GetExpenseMetricsCommand(repository: repository);
    metrics = ExpenseMetricsEntity(
      id: 'metrics-id',
      totalAmount: 389205,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      categories: const [
        ExpenseCategoryMetricsEntity(
          category: 'housing',
          totalAmount: 216000,
          percentage: 55.50,
        ),
      ],
    );
  });

  tearDown(() => command.dispose());

  test('starts without a result or a repository query', () {
    expect(command.execute.value, isNull);
    expect(command.execute.isRunning.value, isFalse);
    verifyZeroInteractions(repository);
  });

  test(
    'delegates null filters without choosing a period or grouping',
    () async {
      final response = Right<ErrorsEntity, ExpenseMetricsEntity>(metrics);
      when(() => repository.getExpenses()).thenAnswer((_) async => response);

      final result = await command.execute.runAsync(defaultFilters);

      expect(result, same(response));
      expect(command.execute.value, same(response));
      expect(command.execute.value?.right, same(metrics));
      verify(() => repository.getExpenses()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('delegates explicit civil dates and grouping unchanged', () async {
    final startDate = DateTime.utc(2026, 9, 1);
    final endDate = DateTime.utc(2026, 9, 30);
    final response = Right<ErrorsEntity, ExpenseMetricsEntity>(metrics);
    when(
      () => repository.getExpenses(
        startDate: startDate,
        endDate: endDate,
        groupBy: .category,
      ),
    ).thenAnswer((_) async => response);

    final result = await command.execute.runAsync((
      startDate: startDate,
      endDate: endDate,
      groupBy: .category,
    ));

    expect(result, same(response));
    expect(command.execute.value?.right, same(metrics));
    final captured = verify(
      () => repository.getExpenses(
        startDate: captureAny(named: 'startDate'),
        endDate: captureAny(named: 'endDate'),
        groupBy: .category,
      ),
    ).captured;
    expect(captured[0], same(startDate));
    expect(captured[1], same(endDate));
    verifyNoMoreInteractions(repository);
  });

  test(
    'preserves incomplete periods and validation failures as results',
    () async {
      final endDate = DateTime(2026, 10, 31);
      const response = Left<ErrorsEntity, ExpenseMetricsEntity>(
        ErrorsEntity(
          errors: [
            ErrorEntity(
              title: 'Parâmetro inválido',
              detail: 'As datas inicial e final devem ser informadas juntas.',
              status: '422',
              parameter: 'start_date',
            ),
          ],
        ),
      );
      when(() => repository.getExpenses(endDate: endDate, groupBy: .category))
          .thenAnswer((_) async => response);

      final result = await command.execute.runAsync((
        startDate: null,
        endDate: endDate,
        groupBy: .category,
      ));

      expect(result, same(response));
      expect(command.execute.value, same(response));
      expect(result?.left.errors.single.parameter, 'start_date');
      verify(() => repository.getExpenses(endDate: endDate, groupBy: .category))
          .called(1);
    },
  );

  test('allows retry after failure and replaces the previous result', () async {
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Left(ErrorsEntity.unknown()));
    expect((await command.execute.runAsync(defaultFilters))?.isLeft, isTrue);
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Right(metrics));

    await command.execute.runAsync(defaultFilters);
    expect(command.execute.value?.right, same(metrics));

    final emptyMetrics = ExpenseMetricsEntity(
      id: 'empty-period',
      totalAmount: 0,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 30),
      categories: [],
    );
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Right(emptyMetrics));

    await command.execute.runAsync(defaultFilters);

    expect(command.execute.value?.right, same(emptyMetrics));
    expect(command.execute.value?.right.totalAmount, 0);
    expect(command.execute.value?.right.categories, isEmpty);
    verify(() => repository.getExpenses()).called(3);
  });

  test('keeps loading and prevents duplicate queries while pending', () async {
    final pending = Completer<GetExpensesRepositoryType>();
    final started = Completer<void>();
    when(() => repository.getExpenses()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final result = command.execute.runAsync(defaultFilters);
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run(defaultFilters);
    verify(() => repository.getExpenses()).called(1);
    pending.complete(Right(metrics));

    expect((await result)?.right, same(metrics));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('keeps results isolated between command instances', () async {
    final otherCommand = GetExpenseMetricsCommand(repository: repository);
    addTearDown(otherCommand.dispose);
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Right(metrics));

    await command.execute.runAsync(defaultFilters);

    expect(command.execute.value?.right, same(metrics));
    expect(otherCommand.execute.value, isNull);
    expect(otherCommand.execute.isRunning.value, isFalse);
  });

  test('exposes unexpected repository exceptions as command errors', () async {
    final failure = StateError('repository unavailable');
    when(() => repository.getExpenses()).thenAnswer((_) async => throw failure);
    void onResult() {}
    command.execute.results.addListener(onResult);
    try {
      await expectLater(
        command.execute.runAsync(defaultFilters),
        throwsA(same(failure)),
      );
    } finally {
      command.execute.results.removeListener(onResult);
    }
  });

  test('disposes execution and loading observables', () async {
    final disposable = GetExpenseMetricsCommand(repository: repository);
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
}
