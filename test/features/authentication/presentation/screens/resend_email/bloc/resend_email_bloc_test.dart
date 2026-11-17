import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = ResendEmailSubmittedEvent(email: ' Person@Example.com ');
  const started = ResendEmailStartedEvent();
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '429',
        code: 'rate_limit_exceeded',
        pointer: '/email',
        parameter: 'email',
      ),
      ErrorEntity(),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<String> Function() answer) {
    when(() => repository.requestCode(email: submitted.email))
        .thenAnswer((_) => answer());
  }

  ResendEmailBloc readyBloc(FakeAsync async) {
    final bloc = ResendEmailBloc(repository: repository);
    bloc.add(started);
    async.flushMicrotasks();
    async.elapse(const Duration(seconds: 60));
    return bloc;
  }

  group('Initial state and manual resend', () {
    test('starts without requesting another code or starting a timer', () {
      fakeAsync((async) {
        final bloc = ResendEmailBloc(repository: repository);
        expect(bloc.state, isA<ResendEmailInitial>());
        expect(bloc.state.canSubmit, isFalse);
        expect(bloc.state.isSubmitting, isFalse);
        expect(bloc.state.remaining, Duration.zero);
        bloc.add(submitted);
        async.flushMicrotasks();

        expect(bloc.state, isA<ResendEmailInitial>());
        expect(async.periodicTimerCount, 0);
        verifyZeroInteractions(repository);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    blocTest<ResendEmailBloc, ResendEmailState>(
      'resends unchanged email and exposes the returned userId',
      build: () {
        stub(() async => ' service-user ');
        return ResendEmailBloc(repository: repository);
      },
      seed: () => const ResendEmailReady(),
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ResendEmailSubmitting>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
        isA<ResendEmailSuccess>()
            .having((state) => state.userId, 'userId', ' service-user ')
            .having((state) => state.remaining.inSeconds, 'remaining', 60)
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
      ],
      verify: (_) {
        verify(() => repository.requestCode(email: submitted.email)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Failures and manual retry', () {
    for (final failure in [errors, const ErrorsEntity(errors: [])]) {
      blocTest<ResendEmailBloc, ResendEmailState>(
        'preserves ${failure.errors.length} application errors without reporting or retrying',
        build: () {
          stub(() async => throw AuthenticationException(errors: failure));
          return ResendEmailBloc(repository: repository);
        },
        seed: () => const ResendEmailReady(),
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<ResendEmailSubmitting>(),
          isA<ResendEmailFailure>()
              .having((state) => state.errors, 'errors', same(failure))
              .having((state) => state.canSubmit, 'canSubmit', isTrue)
              .having((state) => state.isSubmitting, 'isSubmitting', isFalse)
              .having((state) => state.remaining, 'remaining', Duration.zero),
        ],
        errors: () => isEmpty,
        verify: (_) {
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    for (final unexpected in <Object>[
      StateError('private failure'),
      const FormatException('private payload'),
    ]) {
      blocTest<ResendEmailBloc, ResendEmailState>(
        'reports ${unexpected.runtimeType} with a safe retryable fallback',
        build: () {
          stub(() async => throw unexpected);
          return ResendEmailBloc(repository: repository);
        },
        seed: () => const ResendEmailReady(),
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<ResendEmailSubmitting>(),
          isA<ResendEmailFailure>()
              .having(
                (state) => state.errors.errors.single.title,
                'title',
                'Erro desconhecido',
              )
              .having(
                (state) => state.errors.errors.single.detail,
                'detail',
                'Não foi possível processar a resposta.',
              )
              .having((state) => state.canSubmit, 'canSubmit', isTrue),
        ],
        errors: () => [same(unexpected)],
      );
    }

    blocTest<ResendEmailBloc, ResendEmailState>(
      'allows immediate manual retry after failure',
      build: () {
        int attempts = 0;
        stub(() async {
          if (++attempts == 1) {
            throw AuthenticationException(errors: errors);
          }
          return 'retry-user';
        });
        return ResendEmailBloc(repository: repository);
      },
      seed: () => const ResendEmailReady(),
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ResendEmailFailure,
        );
        bloc.add(submitted);
        await failed;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailFailure>(),
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailSuccess>().having(
          (state) => state.userId,
          'userId',
          'retry-user',
        ),
      ],
      verify: (_) =>
          verify(() => repository.requestCode(email: submitted.email))
              .called(2),
    );
  });

  group('Cooldown with virtual time', () {
    test(
      'starts from an already requested code without requesting it again',
      () {
        fakeAsync((async) {
          final bloc = ResendEmailBloc(repository: repository);
          bloc.add(started);
          async.flushMicrotasks();

          expect(bloc.state, isA<ResendEmailCooldown>());
          expect(bloc.state.remaining, const Duration(seconds: 60));
          expect(bloc.state.canSubmit, isFalse);
          bloc.add(started);
          bloc.add(submitted);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 59));
          expect(bloc.state.remaining, const Duration(seconds: 1));
          bloc.add(submitted);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 1));

          expect(bloc.state, isA<ResendEmailReady>());
          expect(bloc.state.remaining, Duration.zero);
          expect(bloc.state.canSubmit, isTrue);
          async.elapse(const Duration(minutes: 2));
          bloc.add(started);
          async.flushMicrotasks();
          expect(bloc.state, isA<ResendEmailReady>());
          verifyZeroInteractions(repository);
          unawaited(bloc.close());
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
        });
      },
    );

    test('each successful manual resend publishes its new userId and restarts cooldown', () {
      fakeAsync((async) {
        int requests = 0;
        stub(() async => 'user-${++requests}');
        final bloc = readyBloc(async);
        bloc.add(submitted);
        async.flushMicrotasks();

        expect((bloc.state as ResendEmailSuccess).userId, 'user-1');
        expect(bloc.state.remaining, const Duration(seconds: 60));
        bloc.add(submitted);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 59));
        expect(bloc.state.remaining, const Duration(seconds: 1));
        expect(bloc.state.canSubmit, isFalse);
        async.elapse(const Duration(seconds: 1));
        async.elapse(const Duration(minutes: 2));
        verify(() => repository.requestCode(email: submitted.email)).called(1);
        bloc.add(submitted);
        async.flushMicrotasks();

        expect((bloc.state as ResendEmailSuccess).userId, 'user-2');
        expect(bloc.state.remaining, const Duration(seconds: 60));
        verify(() => repository.requestCode(email: submitted.email)).called(1);
        verifyNoMoreInteractions(repository);
        unawaited(bloc.close());
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    });

    test(
      'starts the timer only after successful completion, never after failure',
      () {
        fakeAsync((async) {
          final pending = Completer<String>();
          stub(() => pending.future);
          final bloc = readyBloc(async);
          bloc.add(submitted);
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 2));

          expect(bloc.state, isA<ResendEmailSubmitting>());
          expect(bloc.state.remaining, Duration.zero);
          expect(async.periodicTimerCount, 0);
          pending.completeError(AuthenticationException(errors: errors));
          async.flushMicrotasks();
          expect(bloc.state, isA<ResendEmailFailure>());
          expect(async.periodicTimerCount, 0);
          bloc.add(started);
          async.flushMicrotasks();
          expect(bloc.state, isA<ResendEmailFailure>());
          stub(() async => 'new-user');
          bloc.add(submitted);
          async.flushMicrotasks();

          expect(bloc.state.remaining, const Duration(seconds: 60));
          expect(async.periodicTimerCount, 1);
          unawaited(bloc.close());
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
        });
      },
    );

    test('closing during cooldown cancels ticks and prevents late states', () {
      fakeAsync((async) {
        final bloc = ResendEmailBloc(repository: repository);
        final states = <ResendEmailState>[];
        final subscription = bloc.stream.listen(states.add);
        bloc.add(started);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        final count = states.length;

        unawaited(bloc.close());
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));

        expect(async.periodicTimerCount, 0);
        expect(states, hasLength(count));
        expect(bloc.isClosed, isTrue);
        unawaited(subscription.cancel());
        async.flushMicrotasks();
      });
    });

    test('empty addresses do not resend or start another cooldown', () {
      fakeAsync((async) {
        final bloc = readyBloc(async);
        bloc.add(const ResendEmailSubmittedEvent(email: ''));
        async.flushMicrotasks();

        expect(bloc.state, isA<ResendEmailReady>());
        expect(async.periodicTimerCount, 0);
        verifyZeroInteractions(repository);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });

  group('Concurrency and lifecycle', () {
    test(
      'dropped resends do not retry automatically after a pending failure',
      () {
        fakeAsync((async) {
          final pending = Completer<String>();
          stub(() => pending.future);
          final bloc = readyBloc(async);
          bloc.add(submitted);
          async.flushMicrotasks();
          bloc.add(submitted);
          bloc.add(const ResendEmailSubmittedEvent(email: 'other@example.com'));
          async.flushMicrotasks();
          stub(() async => 'new-user');
          pending.completeError(AuthenticationException(errors: errors));
          async.flushMicrotasks();

          expect(bloc.state, isA<ResendEmailFailure>());
          expect(async.periodicTimerCount, 0);
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
          bloc.add(submitted);
          async.flushMicrotasks();
          expect((bloc.state as ResendEmailSuccess).userId, 'new-user');
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
          unawaited(bloc.close());
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
        });
      },
    );

    test(
      'drops duplicate and different emails while pending instead of queueing',
      () {
        fakeAsync((async) {
          final pending = Completer<String>();
          stub(() => pending.future);
          final bloc = readyBloc(async);
          bloc.add(submitted);
          async.flushMicrotasks();
          bloc.add(submitted);
          bloc.add(const ResendEmailSubmittedEvent(email: 'other@example.com'));
          async.flushMicrotasks();

          expect(bloc.state, isA<ResendEmailSubmitting>());
          pending.complete('user');
          async.flushMicrotasks();
          expect(bloc.state, isA<ResendEmailSuccess>());
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
          unawaited(bloc.close());
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
        });
      },
    );

    for (final outcome in [
      'success',
      'expected failure',
      'unexpected failure',
    ]) {
      test('closing prevents late states for $outcome', () {
        fakeAsync((async) {
          final pending = Completer<String>();
          stub(() => pending.future);
          final bloc = readyBloc(async);
          final states = <ResendEmailState>[];
          final subscription = bloc.stream.listen(states.add);
          bloc.add(submitted);
          async.flushMicrotasks();
          unawaited(bloc.close());
          switch (outcome) {
            case 'success':
              pending.complete('user');
            case 'expected failure':
              pending.completeError(AuthenticationException(errors: errors));
            default:
              pending.completeError(StateError('late error'));
          }
          async.flushMicrotasks();

          expect(bloc.isClosed, isTrue);
          expect(states, [isA<ResendEmailSubmitting>()]);
          expect(async.periodicTimerCount, 0);
          unawaited(subscription.cancel());
          async.flushMicrotasks();
        });
      });
    }

    test('keeps externally owned instances independent', () {
      fakeAsync((async) {
        stub(() async => 'user');
        final first = readyBloc(async);
        final second = ResendEmailBloc(repository: repository);

        first.add(submitted);
        async.flushMicrotasks();

        expect(first.state, isA<ResendEmailSuccess>());
        expect(second.state, isA<ResendEmailInitial>());
        verify(() => repository.requestCode(email: submitted.email)).called(1);
        verifyNoMoreInteractions(repository);
        unawaited(first.close());
        unawaited(second.close());
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    });
  });
}
