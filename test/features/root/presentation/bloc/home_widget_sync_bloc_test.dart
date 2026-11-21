import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_state.dart';

import '../../../../support/root/mocks/home_widget_sync_repository_mock.dart';

void main() {
  late HomeWidgetSyncRepositoryMock repository;
  setUp(() {
    repository = HomeWidgetSyncRepositoryMock();
    when(repository.enable).thenAnswer((_) async {});
    when(repository.refresh).thenAnswer((_) async {});
  });

  test('starts idle without touching native state or metrics', () async {
    final bloc = HomeWidgetSyncBloc(repository: repository);
    addTearDown(bloc.close);

    expect(bloc.state, isA<HomeWidgetSyncInitial>());
    verifyZeroInteractions(repository);
  });

  test(
    'startup refreshes locally and owns a single mutation observation',
    () async {
      final subscribed = Completer<void>();
      final refreshes = StreamController<void>(onListen: subscribed.complete);
      when(() => repository.refreshRequests)
          .thenAnswer((_) => refreshes.stream);
      final bloc = HomeWidgetSyncBloc(repository: repository);
      final ready = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );

      bloc.add(const HomeWidgetSyncStartedEvent());
      await subscribed.future;
      await ready;
      bloc.add(const HomeWidgetSyncStartedEvent());
      final refreshed = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );
      refreshes.add(null);
      await refreshed;

      verify(repository.enable).called(2);
      verify(repository.refresh).called(2);
      verify(() => repository.refreshRequests).called(1);
      await bloc.close();
      expect(refreshes.hasListener, isFalse);
      await refreshes.close();
    },
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'refresh enables publication before querying monthly metrics',
    build: () => HomeWidgetSyncBloc(repository: repository),
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncReady>()],
    verify: (_) => verifyInOrder([repository.enable, repository.refresh]),
  );

  test('waits for native enable before querying metrics', () async {
    final started = Completer<void>();
    final enabled = Completer<void>();
    when(repository.enable).thenAnswer((_) {
      started.complete();
      return enabled.future;
    });
    final bloc = HomeWidgetSyncBloc(repository: repository);
    addTearDown(bloc.close);
    final ready = bloc.stream.firstWhere(
      (state) => state is HomeWidgetSyncReady,
    );

    bloc.add(const HomeWidgetRefreshRequestedEvent());
    await started.future;
    verifyNever(repository.refresh);
    enabled.complete();
    await ready;

    verify(repository.refresh).called(1);
  });

  test('closing while enabling prevents a late metrics query', () async {
    final started = Completer<void>();
    final enabled = Completer<void>();
    when(repository.enable).thenAnswer((_) {
      started.complete();
      return enabled.future;
    });
    final bloc = HomeWidgetSyncBloc(repository: repository);
    bloc.add(const HomeWidgetRefreshRequestedEvent());
    await started.future;

    final closing = bloc.close();
    enabled.complete();
    await closing;

    verifyNever(repository.refresh);
    expect(bloc.isClosed, isTrue);
  });

  final errors = ErrorsEntity.unknown();
  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'an explicit refresh retries after failure without automatic retry',
    build: () => HomeWidgetSyncBloc(repository: repository),
    seed: () => HomeWidgetSyncFailure(errors: errors),
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncReady>()],
    verify: (_) => verify(repository.refresh).called(1),
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'preserves expected errors without zeroing the native summary',
    build: () {
      when(repository.refresh).thenThrow(MetricsException(errors: errors));
      return HomeWidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [
      isA<HomeWidgetSyncUpdating>(),
      isA<HomeWidgetSyncFailure>().having(
        (state) => state.errors,
        'errors',
        same(errors),
      ),
    ],
    errors: () => isEmpty,
    verify: (_) => verify(repository.refresh).called(1),
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'reports unexpected failures with a safe state and no automatic retry',
    build: () {
      when(repository.refresh).thenThrow(StateError('unexpected'));
      return HomeWidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncFailure>()],
    errors: () => [isA<StateError>()],
    verify: (_) => verify(repository.refresh).called(1),
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'native enable failure prevents querying metrics',
    build: () {
      when(repository.enable).thenThrow(StateError('native failure'));
      return HomeWidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncFailure>()],
    errors: () => [isA<StateError>()],
    verify: (_) => verifyNever(repository.refresh),
  );

  late StreamController<void> refreshes;
  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'stream failures report an error but keep later refreshes working',
    build: () {
      refreshes = StreamController<void>();
      when(() => repository.refreshRequests)
          .thenAnswer((_) => refreshes.stream);
      return HomeWidgetSyncBloc(repository: repository);
    },
    act: (bloc) async {
      final ready = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );
      bloc.add(const HomeWidgetSyncStartedEvent());
      await ready;
      final refreshed = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );
      refreshes.addError(StateError('stream failure'));
      refreshes.add(null);
      await refreshed;
    },
    expect: () => [
      isA<HomeWidgetSyncUpdating>(),
      isA<HomeWidgetSyncReady>(),
      isA<HomeWidgetSyncUpdating>(),
      isA<HomeWidgetSyncReady>(),
    ],
    errors: () => [isA<StateError>()],
    tearDown: () => refreshes.close(),
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'observation setup failure is reported without querying metrics',
    build: () {
      when(() => repository.refreshRequests)
          .thenThrow(StateError('observation failed'));
      return HomeWidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const HomeWidgetSyncStartedEvent()),
    expect: () => [],
    errors: () => [isA<StateError>()],
    verify: (_) => verifyNever(repository.refresh),
  );

  for (final outcome in ['success', 'expected failure', 'unexpected failure']) {
    test('closing ignores late $outcome from a pending refresh', () async {
      final started = Completer<void>();
      final pending = Completer<void>();
      when(repository.refresh).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final bloc = HomeWidgetSyncBloc(repository: repository);
      final states = <HomeWidgetSyncState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      bloc.add(const HomeWidgetRefreshRequestedEvent());
      await started.future;

      final closing = bloc.close();
      switch (outcome) {
        case 'success':
          pending.complete();
        case 'expected failure':
          pending.completeError(MetricsException(errors: errors));
        default:
          pending.completeError(StateError('late failure'));
      }
      await closing;

      expect(states, [isA<HomeWidgetSyncUpdating>()]);
      expect(bloc.isClosed, isTrue);
    });
  }

  test(
    'a newer refresh supersedes pending work instead of dropping a mutation',
    () async {
      final started = Completer<void>();
      final first = Completer<void>();
      final latest = Completer<void>();
      final refreshed = Completer<void>();
      int refreshCount = 0;
      when(repository.refresh).thenAnswer((_) {
        refreshCount += 1;
        if (refreshCount == 1) {
          started.complete();
          return first.future;
        }
        refreshed.complete();
        return latest.future;
      });
      final bloc = HomeWidgetSyncBloc(repository: repository);
      bloc.add(const HomeWidgetRefreshRequestedEvent());
      await started.future;

      bloc.add(const HomeWidgetRefreshRequestedEvent());
      await refreshed.future;
      final ready = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );
      latest.complete();
      await ready;
      first.complete();
      await bloc.close();

      expect(refreshCount, 2);
      expect(bloc.state, isA<HomeWidgetSyncReady>());
    },
  );
}
