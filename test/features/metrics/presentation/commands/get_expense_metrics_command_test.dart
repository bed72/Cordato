import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';

import '../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  const defaultFilters = (startDate: null, endDate: null, groupBy: null);
  late MetricsRepositoryMock repository;
  late GetExpenseMetricsCommand command;
  late ExpenseMetricsEntity metrics;
  void onResult() {}

  setUp(() {
    repository = MetricsRepositoryMock();
    command = GetExpenseMetricsCommand(repository: repository);
    command.execute.results.addListener(onResult);
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

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

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

      final data = await command.execute.runAsync(defaultFilters);

      expect(data, same(metrics));
      expect(command.execute.value, same(metrics));
      expect(command.execute.results.value.data, same(metrics));
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

    final data = await command.execute.runAsync((
      endDate: endDate,
      groupBy: .category,
      startDate: startDate,
    ));

    expect(data, same(metrics));
    expect(command.execute.value, same(metrics));
    final captured = verify(
      () => repository.getExpenses(
        startDate: captureAny(named: 'startDate'),
        endDate: captureAny(named: 'endDate'),
        groupBy: .category,
      ),
    ).captured;

    expect(captured[1], same(endDate));
    expect(captured[0], same(startDate));
    verifyNoMoreInteractions(repository);
  });

  test('preserves incomplete periods and metadata in typed failures', () async {
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

    await expectLater(
      command.execute.runAsync((
        startDate: null,
        endDate: endDate,
        groupBy: .category,
      )),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(response.left),
        ),
      ),
    );

    final failure =
        command.execute.results.value.error as CommandFailureException;
    expect(failure.errors.errors.single.parameter, 'start_date');
    expect(command.execute.errors.value?.error, same(failure));
    expect(command.execute.value, isNull);
    verify(() => repository.getExpenses(endDate: endDate, groupBy: .category))
        .called(1);
  });

  test('allows retry after failure and replaces the previous result', () async {
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Left(ErrorsEntity.unknown()));
    await expectLater(
      command.execute.runAsync(defaultFilters),
      throwsA(isA<CommandFailureException>()),
    );
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Right(metrics));

    await command.execute.runAsync(defaultFilters);
    expect(command.execute.value, same(metrics));

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

    expect(command.execute.value, same(emptyMetrics));
    expect(command.execute.value?.totalAmount, 0);
    expect(command.execute.value?.categories, isEmpty);
    verify(() => repository.getExpenses()).called(3);
  });

  test('keeps loading and prevents duplicate queries while pending', () async {
    final pending = Completer<GetExpensesRepositoryType>();
    final started = Completer<void>();
    when(() => repository.getExpenses()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });

    final data = command.execute.runAsync(defaultFilters);
    await started.future;
    expect(command.execute.isRunning.value, isTrue);
    command.execute.run(defaultFilters);
    verify(() => repository.getExpenses()).called(1);
    pending.complete(Right(metrics));

    expect(await data, same(metrics));
    expect(command.execute.isRunning.value, isFalse);
    verifyNoMoreInteractions(repository);
  });

  test('keeps results isolated between command instances', () async {
    final otherCommand = GetExpenseMetricsCommand(repository: repository);
    addTearDown(otherCommand.dispose);
    when(() => repository.getExpenses())
        .thenAnswer((_) async => Right(metrics));

    await command.execute.runAsync(defaultFilters);

    expect(command.execute.value, same(metrics));
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
      expect(command.execute.results.value.error, same(failure));
      expect(command.execute.errors.value?.error, same(failure));
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

  test('does not publish metrics after disposal during a query', () async {
    final started = Completer<void>();
    final pending = Completer<GetExpensesRepositoryType>();
    final disposable = GetExpenseMetricsCommand(repository: repository);
    when(() => repository.getExpenses()).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    final execution = disposable.execute.runAsync(defaultFilters);
    await started.future;
    disposable.dispose();
    pending.complete(Right(metrics));

    expect(await execution, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(disposable.execute.value, isNull);
    expect(disposable.execute.results.value.data, isNull);
    verify(() => repository.getExpenses()).called(1);
  });

  test('keeps zero totals and absent grouping as successful data', () async {
    final empty = ExpenseMetricsEntity(
      id: 'empty',
      totalAmount: 0,
      categories: null,
      startDate: DateTime(2026, 10),
      endDate: DateTime(2026, 10, 31),
    );
    when(() => repository.getExpenses()).thenAnswer((_) async => Right(empty));

    expect(await command.execute.runAsync(defaultFilters), same(empty));
    expect(command.execute.results.value.data?.categories, isNull);
    expect(command.execute.results.value.hasError, isFalse);
  });

  test(
    'publishes an empty typed failure instead of a previous total',
    () async {
      when(() => repository.getExpenses())
          .thenAnswer((_) async => Right(metrics));
      await command.execute.runAsync(defaultFilters);
      const errors = ErrorsEntity(errors: []);
      when(() => repository.getExpenses())
          .thenAnswer((_) async => const Left(errors));

      await expectLater(
        command.execute.runAsync(defaultFilters),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );

      expect(command.execute.value, same(metrics));
      expect(command.execute.results.value.data, isNull);
      expect(
        command.execute.errors.value?.error,
        same(command.execute.results.value.error),
      );
    },
  );
}
