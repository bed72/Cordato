import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const opened = ResetPasswordOpened(hasToken: true);
  const submitted = ResetPasswordSubmitted(
    token: 'fixture.reset.token',
    password: ' NewPass1 ',
    passwordConfirm: ' NewPass1 ',
  );
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(status: '400', pointer: '/password', parameter: 'password'),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() {
    repository = AuthenticationRepositoryMock();
    when(() => repository.signOut()).thenAnswer((_) async {});
    when(
      () => repository.confirmPasswordReset(
        token: any(named: 'token'),
        password: any(named: 'password'),
        passwordConfirm: any(named: 'passwordConfirm'),
      ),
    ).thenAnswer((_) async {});
  });

  void stubReset(Future<void> Function() answer) {
    when(
      () => repository.confirmPasswordReset(
        token: any(named: 'token'),
        password: any(named: 'password'),
        passwordConfirm: any(named: 'passwordConfirm'),
      ),
    ).thenAnswer((_) => answer());
  }

  group('Session preparation', () {
    test('starts disabled and without credentials in state', () async {
      final bloc = ResetPasswordBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<ResetPasswordInitial>());
      expect(bloc.state.canSubmit, isFalse);
      verifyZeroInteractions(repository);
    });

    for (final hasToken in [true, false]) {
      blocTest<ResetPasswordBloc, ResetPasswordState>(
        'clears the local session before publishing hasToken=$hasToken',
        build: () => ResetPasswordBloc(repository: repository),
        act: (bloc) => bloc.add(ResetPasswordOpened(hasToken: hasToken)),
        expect: () => [
          isA<ResetPasswordPreparing>(),
          hasToken ? isA<ResetPasswordReady>() : isA<ResetPasswordInvalid>(),
        ],
        verify: (_) {
          verify(() => repository.signOut()).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    }

    test(
      'waits for storage clearance and ignores submissions while preparing',
      () async {
        final pending = Completer<void>();
        when(() => repository.signOut()).thenAnswer((_) => pending.future);
        final bloc = ResetPasswordBloc(repository: repository);
        addTearDown(bloc.close);
        final preparing = bloc.stream.firstWhere(
          (state) => state is ResetPasswordPreparing,
        );
        bloc.add(opened);
        await preparing;
        expect(bloc.state.canSubmit, isFalse);
        bloc.add(submitted);
        final ready = bloc.stream.firstWhere(
          (state) => state is ResetPasswordReady,
        );
        pending.complete();
        await ready;
        verify(() => repository.signOut()).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    final storageFailure = StateError('fixture storage failure');
    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'reports storage failure without enabling reset and permits explicit retry',
      build: () {
        var attempts = 0;
        when(() => repository.signOut()).thenAnswer((_) async {
          if (++attempts == 1) throw storageFailure;
        });
        return ResetPasswordBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ResetPasswordSessionFailure,
        );
        bloc.add(opened);
        await failed;
        bloc.add(submitted);
        bloc.add(opened);
      },
      expect: () => [
        isA<ResetPasswordPreparing>(),
        isA<ResetPasswordSessionFailure>(),
        isA<ResetPasswordPreparing>(),
        isA<ResetPasswordReady>(),
      ],
      errors: () => [same(storageFailure)],
      verify: (_) {
        verify(() => repository.signOut()).called(2);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Password confirmation', () {
    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'delegates credentials unchanged and blocks repeated submission after success',
      build: () => ResetPasswordBloc(repository: repository),
      seed: () => const ResetPasswordReady(),
      act: (bloc) async {
        final success = bloc.stream.firstWhere(
          (state) => state is ResetPasswordSuccess,
        );
        bloc.add(submitted);
        await success;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResetPasswordSubmitting>(),
        isA<ResetPasswordSuccess>(),
      ],
      verify: (_) {
        verify(
          () => repository.confirmPasswordReset(
            token: submitted.token,
            password: submitted.password,
            passwordConfirm: submitted.passwordConfirm,
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'rejects missing submission token without HTTP',
      build: () => ResetPasswordBloc(repository: repository),
      seed: () => const ResetPasswordReady(),
      act: (bloc) => bloc.add(
        const ResetPasswordSubmitted(
          token: '',
          password: 'NewPass1',
          passwordConfirm: 'NewPass1',
        ),
      ),
      expect: () => [isA<ResetPasswordInvalid>()],
      verify: (_) => verifyZeroInteractions(repository),
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'publishes invalid link for an invalid or expired remote token',
      build: () {
        stubReset(
          () async => throw PasswordResetTokenException(errors: errors),
        );
        return ResetPasswordBloc(repository: repository);
      },
      seed: () => const ResetPasswordReady(),
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ResetPasswordSubmitting>(),
        isA<ResetPasswordInvalid>(),
      ],
      errors: () => isEmpty,
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'preserves expected errors and allows manual retry',
      build: () {
        var attempts = 0;
        stubReset(() async {
          if (++attempts == 1) throw AuthenticationException(errors: errors);
        });
        return ResetPasswordBloc(repository: repository);
      },
      seed: () => const ResetPasswordReady(),
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ResetPasswordFailure,
        );
        bloc.add(submitted);
        await failed;
        bloc.add(submitted);
      },
      expect: () => [
        isA<ResetPasswordSubmitting>(),
        isA<ResetPasswordFailure>()
            .having((state) => state.errors, 'errors', same(errors))
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
        isA<ResetPasswordSubmitting>(),
        isA<ResetPasswordSuccess>(),
      ],
      errors: () => isEmpty,
    );

    final unexpected = StateError('fixture failure');
    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'reports unexpected failures with a safe fallback',
      build: () {
        stubReset(() async => throw unexpected);
        return ResetPasswordBloc(repository: repository);
      },
      seed: () => const ResetPasswordReady(),
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ResetPasswordSubmitting>(),
        isA<ResetPasswordFailure>(),
      ],
      errors: () => [same(unexpected)],
    );
  });

  group('Concurrency and disposal', () {
    test('drops duplicate submits during pending reset', () async {
      final pending = Completer<void>();
      stubReset(() => pending.future);
      final bloc = ResetPasswordBloc(repository: repository);
      addTearDown(bloc.close);
      final ready = bloc.stream.firstWhere(
        (state) => state is ResetPasswordReady,
      );
      bloc.add(opened);
      await ready;
      final started = bloc.stream.firstWhere(
        (state) => state is ResetPasswordSubmitting,
      );
      bloc.add(submitted);
      await started;
      bloc.add(submitted);
      final finished = bloc.stream.firstWhere(
        (state) => state is ResetPasswordSuccess,
      );
      pending.complete();
      await finished;
      verify(
        () => repository.confirmPasswordReset(
          token: submitted.token,
          password: submitted.password,
          passwordConfirm: submitted.passwordConfirm,
        ),
      ).called(1);
    });

    test('opening a newer link invalidates a pending reset handler', () async {
      final pending = Completer<void>();
      final signOuts = <Completer<void>>[];
      when(() => repository.signOut()).thenAnswer((_) {
        final signal = Completer<void>()..complete();
        signOuts.add(signal);
        return signal.future;
      });
      stubReset(() => pending.future);
      final bloc = ResetPasswordBloc(repository: repository);
      addTearDown(bloc.close);
      final firstReady = bloc.stream.firstWhere(
        (state) => state is ResetPasswordReady,
      );
      bloc.add(opened);
      await firstReady;
      final started = bloc.stream.firstWhere(
        (state) => state is ResetPasswordSubmitting,
      );
      bloc.add(submitted);
      await started;
      final secondReady = bloc.stream.firstWhere(
        (state) => state is ResetPasswordReady,
      );
      bloc.add(opened);
      await secondReady;
      pending.complete();
      await pending.future;
      expect(bloc.state, isA<ResetPasswordReady>());
      expect(signOuts, hasLength(2));
    });

    for (final operation in ['prepare', 'reset']) {
      for (final fails in [false, true]) {
        test(
          'closing during $operation suppresses late states with failure=$fails',
          () async {
            final pending = Completer<void>();
            if (operation == 'prepare') {
              when(() => repository.signOut())
                  .thenAnswer((_) => pending.future);
            } else {
              stubReset(() => pending.future);
            }
            final bloc = ResetPasswordBloc(repository: repository);
            final ready = bloc.stream.firstWhere(
              (state) => operation == 'prepare'
                  ? state is ResetPasswordPreparing
                  : state is ResetPasswordReady,
            );
            bloc.add(opened);
            await ready;
            if (operation == 'reset') {
              final started = bloc.stream.firstWhere(
                (state) => state is ResetPasswordSubmitting,
              );
              bloc.add(submitted);
              await started;
            }
            final previous = bloc.state;
            final closing = bloc.close();
            if (fails) {
              pending.completeError(AuthenticationException(errors: errors));
            } else {
              pending.complete();
            }
            await closing;
            expect(bloc.state, same(previous));
          },
        );
      }
    }
  });
}
