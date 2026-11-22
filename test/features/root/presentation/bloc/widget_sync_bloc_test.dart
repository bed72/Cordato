import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_state.dart';

import '../../../../support/root/mocks/widget_sync_repository_mock.dart';

void main() {
  late WidgetSyncRepositoryMock repository;
  setUp(() {
    repository = WidgetSyncRepositoryMock();
    when(repository.enable).thenAnswer((_) async {});
    when(repository.refresh).thenAnswer((_) async {});
  });

  test('starts idle without touching native state or metrics', () async {
    final bloc = WidgetSyncBloc(repository: repository);
    addTearDown(bloc.close);

    expect(bloc.state, isA<WidgetSyncInitial>());
    verifyZeroInteractions(repository);
  });

  test(
    'startup refreshes locally and owns a single mutation observation',
    () async {
      final subscribed = Completer<void>();
      final refreshes = StreamController<void>(onListen: subscribed.complete);
      when(() => repository.refreshRequests)
          .thenAnswer((_) => refreshes.stream);
      final bloc = WidgetSyncBloc(repository: repository);
      final ready = bloc.stream.firstWhere((state) => state is WidgetSyncReady);

      bloc.add(const WidgetSyncStartedEvent());
      await subscribed.future;
      await ready;
      bloc.add(const WidgetSyncStartedEvent());
      final refreshed = bloc.stream.firstWhere(
        (state) => state is WidgetSyncReady,
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

  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'refresh enables publication before querying monthly metrics',
    build: () => WidgetSyncBloc(repository: repository),
    act: (bloc) => bloc.add(const WidgetRefreshRequestedEvent()),
    expect: () => [isA<WidgetSyncUpdating>(), isA<WidgetSyncReady>()],
    verify: (_) => verifyInOrder([repository.enable, repository.refresh]),
  );

  test('waits for native enable before querying metrics', () async {
    final started = Completer<void>();
    final enabled = Completer<void>();
    when(repository.enable).thenAnswer((_) {
      started.complete();
      return enabled.future;
    });
    final bloc = WidgetSyncBloc(repository: repository);
    addTearDown(bloc.close);
    final ready = bloc.stream.firstWhere((state) => state is WidgetSyncReady);

    bloc.add(const WidgetRefreshRequestedEvent());
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
    final bloc = WidgetSyncBloc(repository: repository);
    bloc.add(const WidgetRefreshRequestedEvent());
    await started.future;

    final closing = bloc.close();
    enabled.complete();
    await closing;

    verifyNever(repository.refresh);
    expect(bloc.isClosed, isTrue);
  });

  final errors = ErrorsEntity.unknown();
  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'an explicit refresh retries after failure without automatic retry',
    build: () => WidgetSyncBloc(repository: repository),
    seed: () => WidgetSyncFailure(errors: errors),
    act: (bloc) => bloc.add(const WidgetRefreshRequestedEvent()),
    expect: () => [isA<WidgetSyncUpdating>(), isA<WidgetSyncReady>()],
    verify: (_) => verify(repository.refresh).called(1),
  );

  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'preserves expected errors without zeroing the native summary',
    build: () {
      when(repository.refresh).thenThrow(MetricsException(errors: errors));
      return WidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const WidgetRefreshRequestedEvent()),
    expect: () => [
      isA<WidgetSyncUpdating>(),
      isA<WidgetSyncFailure>().having(
        (state) => state.errors,
        'errors',
        same(errors),
      ),
    ],
    errors: () => isEmpty,
    verify: (_) => verify(repository.refresh).called(1),
  );

  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'reports unexpected failures with a safe state and no automatic retry',
    build: () {
      when(repository.refresh).thenThrow(StateError('unexpected'));
      return WidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const WidgetRefreshRequestedEvent()),
    expect: () => [isA<WidgetSyncUpdating>(), isA<WidgetSyncFailure>()],
    errors: () => [isA<StateError>()],
    verify: (_) => verify(repository.refresh).called(1),
  );

  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'native enable failure prevents querying metrics',
    build: () {
      when(repository.enable).thenThrow(StateError('native failure'));
      return WidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const WidgetRefreshRequestedEvent()),
    expect: () => [isA<WidgetSyncUpdating>(), isA<WidgetSyncFailure>()],
    errors: () => [isA<StateError>()],
    verify: (_) => verifyNever(repository.refresh),
  );

  late StreamController<void> refreshes;
  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'stream failures report an error but keep later refreshes working',
    build: () {
      refreshes = StreamController<void>();
      when(() => repository.refreshRequests)
          .thenAnswer((_) => refreshes.stream);
      return WidgetSyncBloc(repository: repository);
    },
    act: (bloc) async {
      final ready = bloc.stream.firstWhere((state) => state is WidgetSyncReady);
      bloc.add(const WidgetSyncStartedEvent());
      await ready;
      final refreshed = bloc.stream.firstWhere(
        (state) => state is WidgetSyncReady,
      );
      refreshes.addError(StateError('stream failure'));
      refreshes.add(null);
      await refreshed;
    },
    expect: () => [
      isA<WidgetSyncUpdating>(),
      isA<WidgetSyncReady>(),
      isA<WidgetSyncUpdating>(),
      isA<WidgetSyncReady>(),
    ],
    errors: () => [isA<StateError>()],
    tearDown: () => refreshes.close(),
  );

  blocTest<WidgetSyncBloc, WidgetSyncState>(
    'observation setup failure is reported without querying metrics',
    build: () {
      when(() => repository.refreshRequests)
          .thenThrow(StateError('observation failed'));
      return WidgetSyncBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const WidgetSyncStartedEvent()),
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
      final bloc = WidgetSyncBloc(repository: repository);
      final states = <WidgetSyncState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      bloc.add(const WidgetRefreshRequestedEvent());
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

      expect(states, [isA<WidgetSyncUpdating>()]);
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
      final bloc = WidgetSyncBloc(repository: repository);
      bloc.add(const WidgetRefreshRequestedEvent());
      await started.future;

      bloc.add(const WidgetRefreshRequestedEvent());
      await refreshed.future;
      final ready = bloc.stream.firstWhere((state) => state is WidgetSyncReady);
      latest.complete();
      await ready;
      first.complete();
      await bloc.close();

      expect(refreshCount, 2);
      expect(bloc.state, isA<WidgetSyncReady>());
    },
  );
}
