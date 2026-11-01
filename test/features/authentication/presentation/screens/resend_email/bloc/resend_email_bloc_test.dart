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
  const initialRequest = ResendEmailStartedEvent(email: ' Person@Example.com ');
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '429',
        title: 'Aguarde',
        detail: 'Tente novamente.',
        pointer: '/email',
        parameter: 'email',
      ),
      ErrorEntity(),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<void> Function() answer) {
    when(() => repository.resendEmail(email: any(named: 'email')))
        .thenAnswer((_) => answer());
  }

  group('Initial state and verification requests', () {
    test(
      'blocks manual resend until the screen requests initial delivery',
      () async {
        final bloc = ResendEmailBloc(repository: repository);
        addTearDown(bloc.close);
        expect(bloc.state, isA<ResendEmailInitial>());
        expect(bloc.state.canSubmit, isFalse);
        expect(bloc.state.isSubmitting, isFalse);
        verifyZeroInteractions(repository);
      },
    );

    blocTest<ResendEmailBloc, ResendEmailState>(
      'initial request delegates the email unchanged and starts cooldown',
      build: () {
        stub(() async {});
        return ResendEmailBloc(repository: repository);
      },
      act: (bloc) async {
        final finished = bloc.stream.firstWhere(
          (state) => state is ResendEmailSuccess,
        );
        bloc.add(initialRequest);
        await finished;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResendEmailSubmitting>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
        isA<ResendEmailSuccess>()
            .having((state) => state.isInitialRequest, 'initial', isTrue)
            .having((state) => state.remaining.inSeconds, 'remaining', 60)
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
      ],
      verify: (_) {
        verify(() => repository.resendEmail(email: submitted.email)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Failures and manual retry', () {
    blocTest<ResendEmailBloc, ResendEmailState>(
      'initial delivery failure preserves errors and enables manual resend',
      build: () {
        stub(() async => throw AuthenticationException(errors: errors));
        return ResendEmailBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ResendEmailFailure,
        );
        bloc.add(initialRequest);
        await failed;
        bloc.add(initialRequest);
      },
      expect: () => [
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailFailure>()
            .having((state) => state.errors, 'errors', same(errors))
            .having((state) => state.isInitialRequest, 'initial', isTrue)
            .having((state) => state.canSubmit, 'canSubmit', isTrue)
            .having((state) => state.remaining, 'remaining', Duration.zero),
      ],
      verify: (_) =>
          verify(() => repository.resendEmail(email: submitted.email))
              .called(1),
      errors: () => isEmpty,
    );

    for (final failure in [errors, const ErrorsEntity(errors: [])]) {
      blocTest<ResendEmailBloc, ResendEmailState>(
        'preserves ${failure.errors.length} application errors without reporting them',
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
              .having((state) => state.canSubmit, 'canSubmit', isTrue),
        ],
        errors: () => isEmpty,
      );
    }

    final unexpected = StateError('private failure');
    blocTest<ResendEmailBloc, ResendEmailState>(
      'reports unexpected failures and publishes a safe fallback',
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
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
      errors: () => [same(unexpected)],
    );

    blocTest<ResendEmailBloc, ResendEmailState>(
      'allows immediate manual retry after failure then starts cooldown',
      build: () {
        var attempts = 0;
        stub(() async {
          if (++attempts == 1) throw AuthenticationException(errors: errors);
        });
        return ResendEmailBloc(repository: repository);
      },
      act: (bloc) async {
        final failure = bloc.stream.firstWhere(
          (state) => state is ResendEmailFailure,
        );
        bloc.add(initialRequest);
        await failure;
        expect(bloc.state.canSubmit, isTrue);
        expect(bloc.state.remaining, Duration.zero);
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailFailure>().having(
          (state) => state.isInitialRequest,
          'initial',
          isTrue,
        ),
        isA<ResendEmailSubmitting>(),
        isA<ResendEmailSuccess>(),
      ],
      verify: (_) =>
          verify(() => repository.resendEmail(email: submitted.email))
              .called(2),
    );
  });

  group('Cooldown with virtual time', () {
    test(
      'counts 60 seconds, drops early resends and never resends automatically',
      () {
        fakeAsync((async) {
          stub(() async {});
          final bloc = ResendEmailBloc(repository: repository);
          bloc.add(initialRequest);
          async.flushMicrotasks();

          expect(bloc.state, isA<ResendEmailSuccess>());
          expect(bloc.state.remaining, const Duration(seconds: 60));
          expect(bloc.state.canSubmit, isFalse);

          bloc.add(submitted);
          bloc.add(initialRequest);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 59));
          expect(bloc.state.remaining, const Duration(seconds: 1));
          expect(bloc.state.canSubmit, isFalse);
          bloc.add(submitted);
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 1));
          expect(bloc.state, isA<ResendEmailReady>());
          expect(bloc.state.remaining, Duration.zero);
          expect(bloc.state.canSubmit, isTrue);
          async.elapse(const Duration(minutes: 2));
          verify(() => repository.resendEmail(email: submitted.email))
              .called(1);

          bloc.add(initialRequest);
          async.flushMicrotasks();
          verifyNoMoreInteractions(repository);
          bloc.add(submitted);
          async.flushMicrotasks();
          expect(bloc.state, isA<ResendEmailSuccess>());
          expect((bloc.state as ResendEmailSuccess).isInitialRequest, isFalse);
          expect(bloc.state.remaining, const Duration(seconds: 60));
          verify(() => repository.resendEmail(email: submitted.email))
              .called(1);

          unawaited(bloc.close());
          async.flushMicrotasks();
          expect(async.periodicTimerCount, 0);
        });
      },
    );

    test('starts cooldown only after the HTTP operation succeeds', () {
      fakeAsync((async) {
        final pending = Completer<void>();
        stub(() => pending.future);
        final bloc = ResendEmailBloc(repository: repository);
        bloc.add(initialRequest);
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 2));
        expect(bloc.state, isA<ResendEmailSubmitting>());
        expect(bloc.state.remaining, Duration.zero);
        expect(bloc.state.canSubmit, isFalse);
        expect(async.periodicTimerCount, 0);

        pending.complete();
        async.flushMicrotasks();
        expect(bloc.state.remaining, const Duration(seconds: 60));
        expect(async.periodicTimerCount, 1);

        unawaited(bloc.close());
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    });

    test('closing during cooldown cancels ticks and prevents late states', () {
      fakeAsync((async) {
        stub(() async {});
        final bloc = ResendEmailBloc(repository: repository);
        final states = <ResendEmailState>[];
        final subscription = bloc.stream.listen(states.add);
        bloc.add(initialRequest);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        final count = states.length;

        unawaited(bloc.close());
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
        async.elapse(const Duration(minutes: 2));
        expect(states, hasLength(count));
        expect(bloc.isClosed, isTrue);
        unawaited(subscription.cancel());
        async.flushMicrotasks();
      });
    });

    test('empty addresses do not request delivery or start cooldown', () {
      fakeAsync((async) {
        final bloc = ResendEmailBloc(repository: repository);
        bloc.add(const ResendEmailStartedEvent(email: ''));
        async.flushMicrotasks();
        expect(bloc.state, isA<ResendEmailInitial>());
        expect(bloc.state.canSubmit, isFalse);
        expect(async.periodicTimerCount, 0);
        verifyZeroInteractions(repository);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });
  });

  group('Concurrency and lifecycle', () {
    test(
      'drops duplicate and different emails while pending instead of queueing',
      () async {
        final pending = Completer<void>();
        final started = Completer<void>();
        stub(() {
          started.complete();
          return pending.future;
        });
        final bloc = ResendEmailBloc(repository: repository);
        addTearDown(bloc.close);
        bloc.add(initialRequest);
        await started.future;
        bloc.add(submitted);
        bloc.add(const ResendEmailSubmittedEvent(email: 'other@example.com'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<ResendEmailSubmitting>());
        final finished = bloc.stream.firstWhere(
          (state) => state is ResendEmailSuccess,
        );
        pending.complete();
        await finished;
        await Future<void>.delayed(Duration.zero);
        verify(() => repository.resendEmail(email: submitted.email)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    for (final outcome in [
      'success',
      'expected failure',
      'unexpected failure',
    ]) {
      test('closing prevents late states for $outcome', () async {
        final pending = Completer<void>();
        final started = Completer<void>();
        stub(() {
          started.complete();
          return pending.future;
        });
        final bloc = ResendEmailBloc(repository: repository);
        final states = <ResendEmailState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);
        addTearDown(bloc.close);
        bloc.add(initialRequest);
        await started.future;
        final closing = bloc.close();
        switch (outcome) {
          case 'success':
            pending.complete();
          case 'expected failure':
            pending.completeError(AuthenticationException(errors: errors));
          default:
            pending.completeError(StateError('late error'));
        }
        await closing;
        expect(bloc.isClosed, isTrue);
        expect(states, [isA<ResendEmailSubmitting>()]);
      });
    }

    test('keeps screen-owned instances independent', () async {
      stub(() async {});
      final first = ResendEmailBloc(repository: repository);
      final second = ResendEmailBloc(repository: repository);
      addTearDown(first.close);
      addTearDown(second.close);
      final finished = first.stream.firstWhere(
        (state) => state is ResendEmailSuccess,
      );
      first.add(initialRequest);
      await finished;
      expect(second.state, isA<ResendEmailInitial>());
    });
  });
}
