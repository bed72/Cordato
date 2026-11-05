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
    when(() => repository.setSessionActive(active: any(named: 'active')))
        .thenAnswer((_) async {});
    when(repository.refresh).thenAnswer((_) async {});
  });

  test('starts inactive', () async {
    final bloc = HomeWidgetSyncBloc(repository: repository);
    expect(bloc.state, isA<HomeWidgetSyncInactive>());
    await bloc.close();
  });

  test(
    'owns refresh observation through the repository and cancels it on close',
    () async {
      final subscribed = Completer<void>();
      final refreshes = StreamController<void>(onListen: subscribed.complete);
      when(() => repository.refreshRequests)
          .thenAnswer((_) => refreshes.stream);
      final bloc = HomeWidgetSyncBloc(repository: repository);
      bloc.add(const HomeWidgetSyncStartedEvent());
      await subscribed.future;
      final ready = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );
      bloc.add(const HomeWidgetSessionChangedEvent(authenticated: true));
      await ready;

      bloc.add(const HomeWidgetSyncStartedEvent());
      final synchronized = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );
      refreshes.add(null);
      await synchronized;

      verify(repository.refresh).called(2);
      verify(() => repository.refreshRequests).called(1);
      await bloc.close();
      expect(refreshes.hasListener, isFalse);
      await refreshes.close();
    },
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'activation waits for session activation before fetching monthly metrics',
    build: () => HomeWidgetSyncBloc(repository: repository),
    act: (bloc) =>
        bloc.add(const HomeWidgetSessionChangedEvent(authenticated: true)),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncReady>()],
    verify: (_) => verifyInOrder([
      () => repository.setSessionActive(active: true),
      repository.refresh,
    ]),
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'ignores mutation requests while signed out',
    build: () => HomeWidgetSyncBloc(repository: repository),
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [],
    verify: (_) => verifyNever(repository.refresh),
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'refreshes after a mutation without changing the session',
    build: () => HomeWidgetSyncBloc(repository: repository),
    seed: () => const HomeWidgetSyncReady(),
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncReady>()],
    verify: (_) {
      verify(repository.refresh).called(1);
      verifyNever(
        () => repository.setSessionActive(active: any(named: 'active')),
      );
    },
  );

  final errors = ErrorsEntity.unknown();
  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'a new refresh request retries after failure without an automatic retry',
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
    seed: () => const HomeWidgetSyncReady(),
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [
      isA<HomeWidgetSyncUpdating>(),
      isA<HomeWidgetSyncFailure>().having(
        (state) => state.errors,
        'errors',
        same(errors),
      ),
    ],
  );

  blocTest<HomeWidgetSyncBloc, HomeWidgetSyncState>(
    'reports unexpected failures with a safe failure state',
    build: () {
      when(repository.refresh).thenThrow(StateError('unexpected'));
      return HomeWidgetSyncBloc(repository: repository);
    },
    seed: () => const HomeWidgetSyncReady(),
    act: (bloc) => bloc.add(const HomeWidgetRefreshRequestedEvent()),
    expect: () => [isA<HomeWidgetSyncUpdating>(), isA<HomeWidgetSyncFailure>()],
    errors: () => [isA<StateError>()],
  );

  test(
    'logout invalidates a pending refresh and ignores its late completion',
    () async {
      final refreshing = Completer<void>();
      final pending = Completer<void>();
      when(repository.refresh).thenAnswer((_) {
        refreshing.complete();
        return pending.future;
      });
      final bloc = HomeWidgetSyncBloc(repository: repository);
      bloc.add(const HomeWidgetSessionChangedEvent(authenticated: true));
      await refreshing.future;
      final inactive = bloc.stream.firstWhere(
        (state) => state is HomeWidgetSyncInactive,
      );

      bloc.add(const HomeWidgetSessionChangedEvent(authenticated: false));
      await inactive;
      pending.complete();
      await bloc.close();

      expect(bloc.state, isA<HomeWidgetSyncInactive>());
      verify(() => repository.setSessionActive(active: false)).called(1);
    },
  );

  test('closing with a pending refresh publishes no late state', () async {
    final refreshing = Completer<void>();
    final pending = Completer<void>();
    when(repository.refresh).thenAnswer((_) {
      refreshing.complete();
      return pending.future;
    });
    final bloc = HomeWidgetSyncBloc(repository: repository);
    bloc.add(const HomeWidgetSessionChangedEvent(authenticated: true));
    await refreshing.future;

    final closing = bloc.close();
    pending.complete();
    await closing;

    expect(bloc.state, isA<HomeWidgetSyncUpdating>());
  });

  test(
    'a newer refresh supersedes pending work instead of dropping a mutation',
    () async {
      final started = Completer<void>();
      final first = Completer<void>();
      final latest = Completer<void>();
      final refreshed = Completer<void>();
      var refreshCount = 0;
      when(repository.refresh).thenAnswer((_) {
        refreshCount++;
        if (refreshCount == 1) {
          started.complete();
          return first.future;
        }
        refreshed.complete();
        return latest.future;
      });
      final bloc = HomeWidgetSyncBloc(repository: repository);
      bloc.add(const HomeWidgetSessionChangedEvent(authenticated: true));
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
