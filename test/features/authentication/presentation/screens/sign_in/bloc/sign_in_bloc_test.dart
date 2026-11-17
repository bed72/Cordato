import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = SignInSubmittedEvent(email: ' Person@Example.com ');
  const userId = ' service-user ';
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '429',
        code: 'rate_limit_exceeded',
        pointer: '/email',
      ),
      ErrorEntity(status: '400', parameter: 'email'),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<String> Function() answer) {
    when(() => repository.requestCode(email: submitted.email))
        .thenAnswer((_) => answer());
  }

  group('Initial state and code request', () {
    test('starts ready without requesting a code', () async {
      final bloc = SignInBloc(repository: repository);
      addTearDown(bloc.close);

      expect(bloc.state, isA<SignInInitial>());
      expect(bloc.state.canSubmit, isTrue);
      expect(bloc.state.isSubmitting, isFalse);
      verifyZeroInteractions(repository);
    });

    blocTest<SignInBloc, SignInState>(
      'requests unchanged email and exposes only the returned userId',
      build: () {
        stub(() async => userId);
        return SignInBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<SignInSubmitting>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
        isA<SignInSuccess>()
            .having((state) => state.userId, 'userId', userId)
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
      blocTest<SignInBloc, SignInState>(
        'preserves ${failure.errors.length} application errors without reporting them',
        build: () {
          stub(() async => throw AuthenticationException(errors: failure));
          return SignInBloc(repository: repository);
        },
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<SignInSubmitting>(),
          isA<SignInFailure>()
              .having((state) => state.errors, 'errors', same(failure))
              .having((state) => state.canSubmit, 'canSubmit', isTrue)
              .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
        ],
        errors: () => isEmpty,
        verify: (_) {
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    blocTest<SignInBloc, SignInState>(
      'allows a manual retry after failure',
      build: () {
        int attempts = 0;
        stub(() async {
          if (++attempts == 1) {
            throw AuthenticationException(errors: errors);
          }
          return userId;
        });
        return SignInBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is SignInFailure,
        );
        bloc.add(submitted);
        await failed;
        bloc.add(submitted);
      },
      expect: () => [
        isA<SignInSubmitting>(),
        isA<SignInFailure>(),
        isA<SignInSubmitting>(),
        isA<SignInSuccess>().having((state) => state.userId, 'userId', userId),
      ],
      verify: (_) =>
          verify(() => repository.requestCode(email: submitted.email))
              .called(2),
    );

    for (final unexpected in <Object>[
      StateError('private failure'),
      const FormatException('private payload'),
    ]) {
      blocTest<SignInBloc, SignInState>(
        'reports ${unexpected.runtimeType} and publishes a safe retryable failure',
        build: () {
          stub(() async => throw unexpected);
          return SignInBloc(repository: repository);
        },
        act: (bloc) => bloc.add(submitted),
        expect: () => [
          isA<SignInSubmitting>(),
          isA<SignInFailure>()
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
  });

  group('Concurrency and lifecycle', () {
    test(
      'dropped submissions do not become automatic retries after failure',
      () {
        fakeAsync((async) {
          final pending = Completer<String>();
          stub(() => pending.future);
          final bloc = SignInBloc(repository: repository);

          bloc.add(submitted);
          async.flushMicrotasks();
          bloc.add(submitted);
          bloc.add(const SignInSubmittedEvent(email: 'other@example.com'));
          async.flushMicrotasks();
          stub(() async => userId);
          pending.completeError(AuthenticationException(errors: errors));
          async.flushMicrotasks();

          expect(bloc.state, isA<SignInFailure>());
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
          bloc.add(submitted);
          async.flushMicrotasks();
          expect(bloc.state, isA<SignInSuccess>());
          verify(() => repository.requestCode(email: submitted.email))
              .called(1);
          verifyNoMoreInteractions(repository);
          unawaited(bloc.close());
          async.flushMicrotasks();
        });
      },
    );

    test('drops duplicate and different emails while pending and blocks after success', () {
      fakeAsync((async) {
        final pending = Completer<String>();
        stub(() => pending.future);
        final bloc = SignInBloc(repository: repository);
        final states = <SignInState>[];
        final subscription = bloc.stream.listen(states.add);

        bloc.add(submitted);
        async.flushMicrotasks();
        bloc.add(submitted);
        bloc.add(const SignInSubmittedEvent(email: 'other@example.com'));
        async.flushMicrotasks();

        expect(bloc.state, isA<SignInSubmitting>());
        verify(() => repository.requestCode(email: submitted.email)).called(1);
        pending.complete(userId);
        async.flushMicrotasks();
        bloc.add(submitted);
        async.flushMicrotasks();

        expect(states, [isA<SignInSubmitting>(), isA<SignInSuccess>()]);
        verifyNoMoreInteractions(repository);
        unawaited(subscription.cancel());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    for (final outcome in [
      'success',
      'expected failure',
      'unexpected failure',
    ]) {
      test('closing during $outcome prevents late states', () async {
        final pending = Completer<String>();
        stub(() => pending.future);
        final bloc = SignInBloc(repository: repository);
        addTearDown(bloc.close);
        final states = <SignInState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final running = bloc.stream.firstWhere(
          (state) => state is SignInSubmitting,
        );

        bloc.add(submitted);
        await running;
        final closing = bloc.close();
        switch (outcome) {
          case 'success':
            pending.complete(userId);
          case 'expected failure':
            pending.completeError(AuthenticationException(errors: errors));
          default:
            pending.completeError(StateError('late failure'));
        }
        await closing;

        expect(bloc.isClosed, isTrue);
        expect(states, [isA<SignInSubmitting>()]);
      });
    }

    test('keeps externally owned instances independent', () async {
      stub(() async => userId);
      final first = SignInBloc(repository: repository);
      final second = SignInBloc(repository: repository);
      addTearDown(first.close);
      addTearDown(second.close);
      final finished = first.stream.firstWhere(
        (state) => state is SignInSuccess,
      );

      first.add(submitted);
      await finished;

      expect(second.state, isA<SignInInitial>());
      verify(() => repository.requestCode(email: submitted.email)).called(1);
      verifyNoMoreInteractions(repository);
    });
  });
}
