import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_event.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const email = ' Person@Example.com ';
  const submitted = PasswordRecoverySubmitted(email: email);
  const editedEmail = ' Other@Example.com ';
  const errors = ErrorsEntity(
    errors: [ErrorEntity(status: '429', pointer: '/email', parameter: 'email')],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<void> Function() answer) {
    when(() => repository.requestPasswordReset(email: any(named: 'email')))
        .thenAnswer((_) => answer());
  }

  group('Initial delivery and failures', () {
    test('starts ready without requesting an email', () async {
      final bloc = PasswordRecoveryBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<PasswordRecoveryInitial>());
      expect(bloc.state.canSubmit, isTrue);
      expect(bloc.state.sentEmail, isNull);
      verifyZeroInteractions(repository);
    });

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'delegates unchanged input and publishes a sent state with cooldown',
      build: () {
        stub(() async {});
        return PasswordRecoveryBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<PasswordRecoverySubmitting>().having(
          (state) => state.canSubmit,
          'canSubmit',
          isFalse,
        ),
        isA<PasswordRecoverySent>()
            .having((state) => state.sentEmail, 'email', email)
            .having((state) => state.remaining.inSeconds, 'remaining', 60),
      ],
      verify: (_) =>
          verify(() => repository.requestPasswordReset(email: email)).called(1),
    );

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'preserves expected errors and permits immediate manual retry',
      build: () {
        var attempts = 0;
        stub(() async {
          if (++attempts == 1) throw AuthenticationException(errors: errors);
        });
        return PasswordRecoveryBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is PasswordRecoveryFailure,
        );
        bloc.add(submitted);
        await failed;
        bloc.add(submitted);
      },
      expect: () => [
        isA<PasswordRecoverySubmitting>(),
        isA<PasswordRecoveryFailure>()
            .having((state) => state.errors, 'errors', same(errors))
            .having((state) => state.canSubmit, 'canSubmit', isTrue)
            .having((state) => state.remaining, 'remaining', Duration.zero),
        isA<PasswordRecoverySubmitting>(),
        isA<PasswordRecoverySent>(),
      ],
      verify: (_) =>
          verify(() => repository.requestPasswordReset(email: email)).called(2),
    );

    final unexpected = StateError('fixture failure');
    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'reports unexpected failures with safe state',
      build: () {
        stub(() async => throw unexpected);
        return PasswordRecoveryBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<PasswordRecoverySubmitting>(),
        isA<PasswordRecoveryFailure>(),
      ],
      errors: () => [same(unexpected)],
    );
  });

  group('Cooldown and resend', () {
    test('does not resend before the first successful delivery', () {
      fakeAsync((async) {
        final bloc = PasswordRecoveryBloc(repository: repository);

        bloc.add(const PasswordRecoveryResendRequested(email: editedEmail));
        async.flushMicrotasks();

        expect(bloc.state, isA<PasswordRecoveryInitial>());
        verifyZeroInteractions(repository);
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('resends to the edited email only after cooldown and restarts it on success', () {
      fakeAsync((async) {
        final pending = Completer<void>();
        var attempts = 0;
        stub(() => ++attempts == 1 ? Future.value() : pending.future);
        final bloc = PasswordRecoveryBloc(repository: repository);

        bloc.add(submitted);
        async.flushMicrotasks();
        bloc.add(const PasswordRecoveryResendRequested(email: editedEmail));
        async.flushMicrotasks();
        verifyNever(() => repository.requestPasswordReset(email: editedEmail));

        async.elapse(const Duration(seconds: 60));
        expect(bloc.state.canSubmit, isTrue);
        bloc.add(const PasswordRecoveryResendRequested(email: editedEmail));
        async.flushMicrotasks();

        expect(bloc.state, isA<PasswordRecoverySubmitting>());
        expect(bloc.state.canSubmit, isFalse);
        expect(bloc.state.sentEmail, email);
        verify(() => repository.requestPasswordReset(email: editedEmail))
            .called(1);
        bloc.add(const PasswordRecoveryResendRequested(email: email));
        async.flushMicrotasks();
        verify(() => repository.requestPasswordReset(email: email)).called(1);

        pending.complete();
        async.flushMicrotasks();
        expect(bloc.state.sentEmail, editedEmail);
        expect(bloc.state.remaining.inSeconds, 60);
        expect(bloc.state.canSubmit, isFalse);

        unawaited(bloc.close());
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    });

    test('shares the 60 second cooldown policy, blocks duplicates and only resends manually', () {
      fakeAsync((async) {
        final pending = Completer<void>();
        var attempts = 0;
        stub(() => ++attempts == 1 ? pending.future : Future.value());
        final bloc = PasswordRecoveryBloc(repository: repository);
        bloc.add(submitted);
        async.flushMicrotasks();
        bloc.add(submitted);
        bloc.add(const PasswordRecoveryResendRequested(email: email));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));
        expect(bloc.state, isA<PasswordRecoverySubmitting>());
        expect(async.periodicTimerCount, 0);
        pending.complete();
        async.flushMicrotasks();
        expect(bloc.state.remaining.inSeconds, 60);
        bloc.add(const PasswordRecoveryResendRequested(email: email));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 59));
        expect(bloc.state.remaining.inSeconds, 1);
        expect(bloc.state.canSubmit, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(bloc.state.canSubmit, isTrue);
        async.elapse(const Duration(minutes: 2));
        verify(() => repository.requestPasswordReset(email: email)).called(1);
        bloc.add(const PasswordRecoveryResendRequested(email: email));
        async.flushMicrotasks();
        expect(bloc.state.remaining.inSeconds, 60);
        verify(() => repository.requestPasswordReset(email: email)).called(1);
        unawaited(bloc.close());
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    });

    blocTest<PasswordRecoveryBloc, PasswordRecoveryState>(
      'edited email resend failure preserves the confirmation screen and allows retry',
      build: () {
        stub(() async => throw AuthenticationException(errors: errors));
        return PasswordRecoveryBloc(repository: repository);
      },
      seed: () =>
          const PasswordRecoverySent(email: email, remaining: Duration.zero),
      act: (bloc) =>
          bloc.add(const PasswordRecoveryResendRequested(email: editedEmail)),
      expect: () => [
        isA<PasswordRecoverySubmitting>().having(
          (state) => state.sentEmail,
          'email',
          email,
        ),
        isA<PasswordRecoveryFailure>()
            .having((state) => state.errors, 'errors', same(errors))
            .having((state) => state.sentEmail, 'email', email)
            .having((state) => state.remaining, 'remaining', Duration.zero)
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
      verify: (_) =>
          verify(() => repository.requestPasswordReset(email: editedEmail))
              .called(1),
    );
  });

  group('Disposal during pending HTTP', () {
    for (final fails in [false, true]) {
      test(
        'closing during HTTP suppresses late states with failure=$fails',
        () async {
          final pending = Completer<void>();
          stub(() => pending.future);
          final bloc = PasswordRecoveryBloc(repository: repository);
          final started = bloc.stream.firstWhere(
            (state) => state is PasswordRecoverySubmitting,
          );
          bloc.add(submitted);
          await started;
          final closing = bloc.close();
          if (fails) {
            pending.completeError(AuthenticationException(errors: errors));
          } else {
            pending.complete();
          }
          await closing;
          expect(bloc.state, isA<PasswordRecoverySubmitting>());
        },
      );
    }
  });
}
