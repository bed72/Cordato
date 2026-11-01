import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../support/session/mocks/session_repository_mock.dart';

void main() {
  late SessionRepositoryMock repository;
  late StreamController<bool> changes;

  setUp(() {
    repository = SessionRepositoryMock();
    changes = StreamController<bool>.broadcast();
    when(() => repository.sessionChanges).thenAnswer((_) => changes.stream);
  });
  tearDown(() async => changes.close());

  test(
    'starts unknown without reading or subscribing before the start event',
    () async {
      final bloc = SessionBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<SessionInitial>());
      expect(changes.hasListener, isFalse);
      verifyZeroInteractions(repository);
    },
  );

  for (final present in [false, true]) {
    blocTest<SessionBloc, SessionState>(
      'loads initial token presence $present then observes changes',
      build: () {
        when(repository.loadSession).thenAnswer((_) async => present);
        return SessionBloc(repository: repository);
      },
      act: (bloc) async {
        final loaded = bloc.stream.firstWhere(
          (state) =>
              state is SessionAuthenticated || state is SessionUnauthenticated,
        );
        bloc.add(const SessionStartedEvent());
        await loaded;
        changes.add(!present);
      },
      expect: () => [
        isA<SessionLoading>(),
        present ? isA<SessionAuthenticated>() : isA<SessionUnauthenticated>(),
        present ? isA<SessionUnauthenticated>() : isA<SessionAuthenticated>(),
      ],
      verify: (_) {
        verify(repository.loadSession).called(1);
        verify(() => repository.sessionChanges).called(1);
        expect(changes.hasListener, isFalse);
      },
    );
  }

  for (final present in [false, true]) {
    test(
      'a stream event $present wins over the stale opposite initial read',
      () async {
        final pending = Completer<bool>();
        final started = Completer<void>();
        when(repository.loadSession).thenAnswer((_) {
          expect(changes.hasListener, isTrue);
          started.complete();
          return pending.future;
        });
        final bloc = SessionBloc(repository: repository);
        addTearDown(bloc.close);
        bloc.add(const SessionStartedEvent());
        await started.future;
        final updated = bloc.stream.firstWhere(
          (state) =>
              state is SessionAuthenticated || state is SessionUnauthenticated,
        );
        changes.add(present);
        await updated;
        pending.complete(!present);
        await Future<void>.delayed(Duration.zero);
        expect(
          bloc.state,
          present ? isA<SessionAuthenticated>() : isA<SessionUnauthenticated>(),
        );
      },
    );
  }

  test(
    'duplicate start events do not create additional reads or subscriptions',
    () async {
      when(repository.loadSession).thenAnswer((_) async => true);
      final bloc = SessionBloc(repository: repository);
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (state) => state is SessionAuthenticated,
      );
      bloc.add(const SessionStartedEvent());
      bloc.add(const SessionStartedEvent());
      await loaded;
      bloc.add(const SessionStartedEvent());
      await Future<void>.delayed(Duration.zero);
      verify(repository.loadSession).called(1);
      verify(() => repository.sessionChanges).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  final failure = StateError('private storage failure');
  const remoteErrors = ErrorsEntity(
    errors: [ErrorEntity(status: '403', detail: 'Refresh not allowed.')],
  );
  blocTest<SessionBloc, SessionState>(
    'preserves expected refresh errors without reporting them as unexpected',
    build: () {
      when(
        repository.loadSession,
      ).thenAnswer((_) async => throw SessionException(errors: remoteErrors));
      return SessionBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere((state) => state is SessionFailure);
      bloc.add(const SessionStartedEvent());
      await failed;
    },
    expect: () => [
      isA<SessionLoading>(),
      isA<SessionFailure>().having(
        (state) => state.errors,
        'errors',
        same(remoteErrors),
      ),
    ],
    errors: () => isEmpty,
  );
  blocTest<SessionBloc, SessionState>(
    'reports an initial read failure and recovers from a later token change',
    build: () {
      when(repository.loadSession).thenAnswer((_) async => throw failure);
      return SessionBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere((state) => state is SessionFailure);
      bloc.add(const SessionStartedEvent());
      await failed;
      changes.add(true);
    },
    expect: () => [
      isA<SessionLoading>(),
      isA<SessionFailure>(),
      isA<SessionAuthenticated>(),
    ],
    errors: () => [same(failure)],
  );

  blocTest<SessionBloc, SessionState>(
    'reports a stale initial read failure without replacing a recent session',
    build: () => SessionBloc(repository: repository),
    act: (bloc) async {
      final pending = Completer<bool>();
      when(repository.loadSession).thenAnswer((_) => pending.future);
      final running = bloc.stream.firstWhere(
        (state) => state is SessionLoading,
      );
      bloc.add(const SessionStartedEvent());
      await running;
      final updated = bloc.stream.firstWhere(
        (state) => state is SessionAuthenticated,
      );
      changes.add(true);
      await updated;
      pending.completeError(failure);
    },
    expect: () => [isA<SessionLoading>(), isA<SessionAuthenticated>()],
    errors: () => [same(failure)],
  );

  blocTest<SessionBloc, SessionState>(
    'handles stream errors safely and continues observing recovery',
    build: () {
      when(repository.loadSession).thenAnswer((_) async => true);
      return SessionBloc(repository: repository);
    },
    act: (bloc) async {
      final loaded = bloc.stream.firstWhere(
        (state) => state is SessionAuthenticated,
      );
      bloc.add(const SessionStartedEvent());
      await loaded;
      final failed = bloc.stream.firstWhere((state) => state is SessionFailure);
      changes.addError(failure);
      await failed;
      changes.add(false);
    },
    expect: () => [
      isA<SessionLoading>(),
      isA<SessionAuthenticated>(),
      isA<SessionFailure>(),
      isA<SessionUnauthenticated>(),
    ],
    errors: () => [same(failure)],
  );

  blocTest<SessionBloc, SessionState>(
    'handles synchronous subscription failures without starting a read',
    build: () {
      when(() => repository.sessionChanges).thenThrow(failure);
      return SessionBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const SessionStartedEvent()),
    expect: () => [isA<SessionLoading>(), isA<SessionFailure>()],
    errors: () => [same(failure)],
    verify: (_) => verifyNever(repository.loadSession),
  );

  blocTest<SessionBloc, SessionState>(
    'a watch failure also takes precedence over a stale initial read',
    build: () => SessionBloc(repository: repository),
    act: (bloc) async {
      final pending = Completer<bool>();
      when(repository.loadSession).thenAnswer((_) => pending.future);
      final running = bloc.stream.firstWhere(
        (state) => state is SessionLoading,
      );
      bloc.add(const SessionStartedEvent());
      await running;
      final failed = bloc.stream.firstWhere((state) => state is SessionFailure);
      changes.addError(failure);
      await failed;
      pending.complete(true);
    },
    expect: () => [isA<SessionLoading>(), isA<SessionFailure>()],
    errors: () => [same(failure)],
  );

  test(
    'repeated token presence does not emit duplicate ready states',
    () async {
      when(repository.loadSession).thenAnswer((_) async => true);
      final bloc = SessionBloc(repository: repository);
      addTearDown(bloc.close);
      final states = <SessionState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final loaded = bloc.stream.firstWhere(
        (state) => state is SessionAuthenticated,
      );
      bloc.add(const SessionStartedEvent());
      await loaded;
      changes.add(true);
      changes.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(states, [isA<SessionLoading>(), isA<SessionAuthenticated>()]);
    },
  );

  for (final fails in [false, true]) {
    test(
      'native close cancels observation and ignores a pending ${fails ? 'error' : 'read'}',
      () async {
        final pending = Completer<bool>();
        final started = Completer<void>();
        when(repository.loadSession).thenAnswer((_) {
          started.complete();
          return pending.future;
        });
        final bloc = SessionBloc(repository: repository);
        final states = <SessionState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);
        addTearDown(bloc.close);
        bloc.add(const SessionStartedEvent());
        await started.future;
        await bloc.close();
        expect(changes.hasListener, isFalse);
        if (fails) {
          pending.completeError(failure);
        } else {
          pending.complete(true);
        }
        changes.add(false);
        await Future<void>.delayed(Duration.zero);
        expect(states, [isA<SessionLoading>()]);
      },
    );
  }
}
