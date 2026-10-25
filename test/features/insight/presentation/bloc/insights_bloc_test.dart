import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/insight/application/exceptions/insight_exception.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_bloc.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_event.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_state.dart';

import '../../../../support/insight/mocks/insight_repository_mock.dart';

void main() {
  late InsightRepositoryMock repository;
  const onboarding = InsightEntity(
    id: 'onboarding',
    type: 'insufficient_history',
    group: 'onboarding',
    title: 'Continue registrando',
    description: 'Cada registro traz contexto.',
    period: null,
  );
  final dated = InsightEntity(
    id: 'dated',
    type: 'future_type',
    group: 'future_group',
    title: ' Título original ',
    description: ' Descrição original ',
    period: InsightPeriodEntity(
      from: DateTime(2026, 7),
      to: DateTime(2026, 9, 30),
    ),
  );
  final data = [dated, onboarding];
  final unexpected = StateError('private repository detail');

  setUp(() => repository = InsightRepositoryMock());

  test('starts idle without querying the repository', () async {
    final bloc = InsightsBloc(repository: repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<InsightsInitial>());
    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.insights, isNull);
    verifyZeroInteractions(repository);
  });

  blocTest<InsightsBloc, InsightsState>(
    'delegates absent filters and preserves order, content and entity identity',
    build: () {
      when(() => repository.get()).thenAnswer((_) async => data);
      return InsightsBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const InsightsRequestedEvent()),
    expect: () => [
      isA<InsightsLoading>().having((s) => s.isLoading, 'loading', true),
      isA<InsightsSuccess>()
          .having((s) => s.insights, 'data', orderedEquals(data))
          .having((s) => s.data.first, 'first entity', same(dated))
          .having((s) => s.data.last, 'last entity', same(onboarding)),
    ],
    verify: (_) {
      verify(() => repository.get()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  for (final filters in [
    (year: 2026, month: 9),
    (year: 2026, month: null),
    (year: null, month: 13),
  ]) {
    blocTest<InsightsBloc, InsightsState>(
      'delegates $filters without defaults or local validation',
      build: () {
        when(() => repository.get(year: filters.year, month: filters.month))
            .thenAnswer((_) async => []);
        return InsightsBloc(repository: repository);
      },
      act: (bloc) => bloc.add(
        InsightsRequestedEvent(year: filters.year, month: filters.month),
      ),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsSuccess>().having((s) => s.data, 'empty success', isEmpty),
      ],
      verify: (_) {
        verify(() => repository.get(year: filters.year, month: filters.month))
            .called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  }

  test(
    'success owns an immutable snapshot without changing the repository list',
    () {
      final source = [onboarding];
      final state = InsightsSuccess(data: source);
      source.clear();
      expect(state.data.single, same(onboarding));
      expect(() => state.data.clear(), throwsUnsupportedError);
      expect(state.isLoading, isFalse);
    },
  );

  for (final errors in [
    const ErrorsEntity(errors: []),
    const ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Filtro inválido',
          status: '422',
          detail: 'Informe o mês.',
          pointer: '/filter/month',
          parameter: 'filter[month]',
        ),
      ],
    ),
  ]) {
    blocTest<InsightsBloc, InsightsState>(
      'preserves expected errors including empty lists: ${errors.errors.length}',
      build: () {
        when(() => repository.get())
            .thenThrow(InsightException(errors: errors));
        return InsightsBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const InsightsRequestedEvent()),
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsFailure>()
            .having((s) => s.errors, 'errors', same(errors))
            .having((s) => s.insights, 'no data', isNull),
      ],
      errors: () => <Object>[],
    );
  }

  blocTest<InsightsBloc, InsightsState>(
    'reports unexpected failures with safe feedback',
    build: () {
      when(() => repository.get()).thenAnswer((_) async => throw unexpected);
      return InsightsBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const InsightsRequestedEvent()),
    expect: () => [
      isA<InsightsLoading>(),
      isA<InsightsFailure>().having(
        (s) => s.errors.errors.single.detail,
        'safe fallback',
        ErrorsEntity.unknown().errors.single.detail,
      ),
    ],
    errors: () => [same(unexpected)],
  );

  test(
    'refresh replaces data and failure allows only a manual retry',
    () async {
      when(() => repository.get()).thenAnswer((_) async => data);
      final bloc = InsightsBloc(repository: repository);
      addTearDown(bloc.close);
      var ready = bloc.stream.firstWhere((s) => s is InsightsSuccess);
      bloc.add(const InsightsRequestedEvent());
      await ready;
      when(() => repository.get())
          .thenThrow(InsightException(errors: const ErrorsEntity(errors: [])));
      ready = bloc.stream.firstWhere((s) => s is InsightsFailure);
      bloc.add(const InsightsRequestedEvent());
      await ready;
      expect(bloc.state.insights, isNull);
      verify(() => repository.get()).called(2);
      when(() => repository.get()).thenAnswer((_) async => []);
      ready = bloc.stream.firstWhere((s) => s is InsightsSuccess);
      bloc.add(const InsightsRequestedEvent());
      await ready;
      expect(bloc.state.insights, isEmpty);
      verify(() => repository.get()).called(1);
    },
  );

  for (final outcome in ['success', 'expected', 'unexpected']) {
    late Completer<List<InsightEntity>> pending;
    late Completer<void> started;

    void completePending() {
      if (outcome == 'success') {
        pending.complete([onboarding]);
      } else {
        pending.completeError(
          outcome == 'expected'
              ? InsightException(errors: ErrorsEntity.unknown())
              : unexpected,
        );
      }
    }

    blocTest<InsightsBloc, InsightsState>(
      'latest query wins over stale $outcome without reporting obsolete errors',
      build: () {
        pending = Completer<List<InsightEntity>>();
        started = Completer<void>();
        when(() => repository.get()).thenAnswer((_) {
          started.complete();
          return pending.future;
        });
        when(() => repository.get(year: 2026, month: 9))
            .thenAnswer((_) async => data);
        return InsightsBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const InsightsRequestedEvent());
        await started.future;
        final ready = bloc.stream.firstWhere((s) => s is InsightsSuccess);
        bloc.add(const InsightsRequestedEvent(year: 2026, month: 9));
        await ready;
        completePending();
        await pending.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
      },
      expect: () => [
        isA<InsightsLoading>(),
        isA<InsightsSuccess>().having(
          (s) => s.data,
          'latest data',
          orderedEquals(data),
        ),
      ],
      errors: () => <Object>[],
    );

    blocTest<InsightsBloc, InsightsState>(
      'close suppresses pending $outcome without canceling HTTP',
      build: () {
        pending = Completer<List<InsightEntity>>();
        started = Completer<void>();
        when(() => repository.get()).thenAnswer((_) {
          started.complete();
          return pending.future;
        });
        return InsightsBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const InsightsRequestedEvent());
        await started.future;
        await bloc.close();
        expect(pending.isCompleted, isFalse);
        completePending();
        await pending.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
      },
      expect: () => [isA<InsightsLoading>()],
      errors: () => <Object>[],
    );
  }

  test('keeps independently owned instances isolated', () async {
    when(() => repository.get()).thenAnswer((_) async => data);
    final first = InsightsBloc(repository: repository);
    final second = InsightsBloc(repository: repository);
    addTearDown(first.close);
    addTearDown(second.close);
    final ready = first.stream.firstWhere((s) => s is InsightsSuccess);
    first.add(const InsightsRequestedEvent());
    await ready;
    expect(second.state, isA<InsightsInitial>());
  });
}
