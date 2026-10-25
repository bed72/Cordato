import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';

import '../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  late MetricsRepositoryMock repository;
  final metrics = ExpenseMetricsEntity(
    id: 'metrics',
    totalAmount: 123,
    startDate: DateTime(2026, 10),
    endDate: DateTime(2026, 10, 31),
    categories: const [],
  );

  setUp(() => repository = MetricsRepositoryMock());

  test('starts idle without querying the repository', () async {
    final bloc = ExpenseMetricsBloc(repository: repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<ExpenseMetricsInitial>());
    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.metrics, isNull);
    verifyZeroInteractions(repository);
  });

  blocTest<ExpenseMetricsBloc, ExpenseMetricsState>(
    'delegates absent filters and preserves the response identity',
    build: () {
      when(() => repository.getExpenses()).thenAnswer((_) async => metrics);
      return ExpenseMetricsBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const ExpenseMetricsRequestedEvent()),
    expect: () => [
      isA<ExpenseMetricsLoading>().having((s) => s.isLoading, 'loading', true),
      isA<ExpenseMetricsSuccess>().having(
        (s) => s.metrics,
        'data',
        same(metrics),
      ),
    ],
    verify: (_) => verify(() => repository.getExpenses()).called(1),
  );

  test(
    'delegates civil dates, grouping and incomplete filters unchanged',
    () async {
      final start = DateTime.utc(2026, 10);
      final end = DateTime.utc(2026, 10, 31);
      when(
        () => repository.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          groupBy: .category,
        ),
      ).thenAnswer((_) async => metrics);
      final bloc = ExpenseMetricsBloc(repository: repository);
      addTearDown(bloc.close);
      var ready = bloc.stream.firstWhere((s) => s is ExpenseMetricsSuccess);
      bloc.add(
        ExpenseMetricsRequestedEvent(
          startDate: start,
          endDate: end,
          groupBy: .category,
        ),
      );
      await ready;
      ready = bloc.stream.firstWhere((s) => s is ExpenseMetricsSuccess);
      bloc.add(ExpenseMetricsRequestedEvent(endDate: end, groupBy: .category));
      await ready;
      final captured = verify(
        () => repository.getExpenses(
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
          groupBy: .category,
        ),
      ).captured;
      expect(captured[0], same(start));
      expect(captured[1], same(end));
      expect(captured[2], isNull);
      expect(captured[3], same(end));
    },
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Filtro inválido',
          detail: 'Informe o período.',
          status: '422',
          parameter: 'start_date',
          pointer: '/data/attributes/start_date',
        ),
      ],
    ),
  ]) {
    blocTest<ExpenseMetricsBloc, ExpenseMetricsState>(
      'preserves expected errors including empty lists: ${errors.errors.length}',
      build: () {
        when(() => repository.getExpenses())
            .thenThrow(MetricsException(errors: errors));
        return ExpenseMetricsBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const ExpenseMetricsRequestedEvent()),
      expect: () => [
        isA<ExpenseMetricsLoading>(),
        isA<ExpenseMetricsFailure>().having(
          (s) => s.errors,
          'errors',
          same(errors),
        ),
      ],
      errors: () => <Object>[],
    );
  }

  final unexpected = StateError('private repository detail');
  blocTest<ExpenseMetricsBloc, ExpenseMetricsState>(
    'reports unexpected errors and publishes a safe fallback',
    build: () {
      when(() => repository.getExpenses()).thenThrow(unexpected);
      return ExpenseMetricsBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const ExpenseMetricsRequestedEvent()),
    expect: () => [
      isA<ExpenseMetricsLoading>(),
      isA<ExpenseMetricsFailure>().having(
        (s) => s.errors.errors.first.detail,
        'fallback',
        ErrorsEntity.unknown().errors.first.detail,
      ),
    ],
    errors: () => [same(unexpected)],
  );

  test(
    'allows manual retry and refresh without retaining stale data',
    () async {
      when(() => repository.getExpenses()).thenAnswer((_) async => metrics);
      final bloc = ExpenseMetricsBloc(repository: repository);
      addTearDown(bloc.close);
      var result = bloc.stream.firstWhere((s) => s is ExpenseMetricsSuccess);
      bloc.add(const ExpenseMetricsRequestedEvent());
      await result;
      when(() => repository.getExpenses())
          .thenThrow(MetricsException(errors: const ErrorsEntity(errors: [])));
      result = bloc.stream.firstWhere((s) => s is ExpenseMetricsFailure);
      bloc.add(const ExpenseMetricsRequestedEvent());
      await result;
      expect(bloc.state.metrics, isNull);
      final empty = ExpenseMetricsEntity(
        id: 'empty',
        totalAmount: 0,
        startDate: metrics.startDate,
        endDate: metrics.endDate,
        categories: null,
      );
      when(() => repository.getExpenses()).thenAnswer((_) async => empty);
      result = bloc.stream.firstWhere((s) => s is ExpenseMetricsSuccess);
      bloc.add(const ExpenseMetricsRequestedEvent());
      await result;
      expect(bloc.state.metrics, same(empty));
      expect(bloc.state.metrics!.totalAmount, 0);
      expect(bloc.state.metrics!.categories, isNull);
      verify(() => repository.getExpenses()).called(3);
    },
  );

  for (final outcome in ['success', 'expected', 'unexpected']) {
    test('latest query wins over stale $outcome', () async {
      final pending = Completer<ExpenseMetricsEntity>();
      final started = Completer<void>();
      when(() => repository.getExpenses()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final end = DateTime(2026, 11, 30);
      when(() => repository.getExpenses(endDate: end))
          .thenAnswer((_) async => metrics);
      final bloc = ExpenseMetricsBloc(repository: repository);
      addTearDown(bloc.close);
      final states = <ExpenseMetricsState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      bloc.add(const ExpenseMetricsRequestedEvent());
      await started.future;
      expect(bloc.state.isLoading, isTrue);
      final ready = bloc.stream.firstWhere((s) => s is ExpenseMetricsSuccess);
      bloc.add(ExpenseMetricsRequestedEvent(endDate: end));
      await ready;
      final confirmed = bloc.state;
      if (outcome == 'success') {
        pending.complete(metrics);
      } else {
        pending.completeError(
          outcome == 'expected'
              ? MetricsException(errors: ErrorsEntity.unknown())
              : unexpected,
        );
      }
      await pending.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      await bloc.close();
      expect(bloc.state, same(confirmed));
      expect(states.whereType<ExpenseMetricsSuccess>(), hasLength(1));
      expect(states.whereType<ExpenseMetricsFailure>(), isEmpty);
    });

    test(
      'closing suppresses pending $outcome without canceling the query',
      () async {
        final pending = Completer<ExpenseMetricsEntity>();
        final started = Completer<void>();
        when(() => repository.getExpenses()).thenAnswer((_) {
          started.complete();
          return pending.future;
        });
        final bloc = ExpenseMetricsBloc(repository: repository);
        bloc.add(const ExpenseMetricsRequestedEvent());
        await started.future;
        await bloc.close();
        if (outcome == 'success') {
          pending.complete(metrics);
        } else {
          pending.completeError(
            outcome == 'expected'
                ? MetricsException(errors: ErrorsEntity.unknown())
                : unexpected,
          );
        }
        await pending.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        expect(bloc.state, isA<ExpenseMetricsLoading>());
        expect(bloc.isClosed, isTrue);
      },
    );
  }

  test('keeps independently owned instances isolated', () async {
    when(() => repository.getExpenses()).thenAnswer((_) async => metrics);
    final first = ExpenseMetricsBloc(repository: repository);
    final second = ExpenseMetricsBloc(repository: repository);
    addTearDown(first.close);
    addTearDown(second.close);
    final ready = first.stream.firstWhere((s) => s is ExpenseMetricsSuccess);
    first.add(const ExpenseMetricsRequestedEvent());
    await ready;
    expect(second.state, isA<ExpenseMetricsInitial>());
  });
}
