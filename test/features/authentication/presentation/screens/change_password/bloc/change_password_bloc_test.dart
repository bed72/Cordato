import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = ChangePasswordSubmitted(
    oldPassword: ' old ',
    password: ' NewPass1 ',
    passwordConfirm: ' NewPass1 ',
  );
  const retry = ChangePasswordSignOutRetried();
  const errors = ErrorsEntity(
    errors: [ErrorEntity(status: '400', pointer: '/oldPassword')],
  );
  late AuthenticationRepositoryMock repository;

  void stubChange(Future<void> Function() answer) {
    when(
      () => repository.changePassword(
        oldPassword: any(named: 'oldPassword'),
        password: any(named: 'password'),
        passwordConfirm: any(named: 'passwordConfirm'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyChangeOnce() {
    verify(
      () => repository.changePassword(
        oldPassword: submitted.oldPassword,
        password: submitted.password,
        passwordConfirm: submitted.passwordConfirm,
      ),
    ).called(1);
  }

  setUp(() {
    repository = AuthenticationRepositoryMock();
    stubChange(() async {});
    when(() => repository.signOut()).thenAnswer((_) async {});
  });

  test('initial state enables submission with no operation', () async {
    final bloc = ChangePasswordBloc(repository: repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<ChangePasswordInitial>());
    expect(bloc.state.canSubmit, isTrue);
    expect(bloc.state.passwordChanged, isFalse);
    verifyZeroInteractions(repository);
  });

  group('Change operation', () {
    const missingIdentity = MissingAuthenticatedUserException();
    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'preserves shared identity failure without reporting or signing out and permits retry',
      build: () {
        stubChange(() async => throw missingIdentity);
        return ChangePasswordBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (state) => state is ChangePasswordFailure,
        );
        bloc.add(submitted);
        await failed;
        verifyNever(repository.signOut);
        stubChange(() async {});
        bloc.add(submitted);
      },
      expect: () => [
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordFailure>()
            .having(
              (state) => state.errors,
              'errors',
              same(missingIdentity.errors),
            )
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSuccess>(),
      ],
      errors: () => isEmpty,
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'delegates exact entries, signs out and ignores events after success',
      build: () => ChangePasswordBloc(repository: repository),
      act: (bloc) async {
        final success = bloc.stream.firstWhere(
          (s) => s is ChangePasswordSuccess,
        );
        bloc.add(submitted);
        await success;
        bloc
          ..add(submitted)
          ..add(retry);
      },
      expect: () => [
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSuccess>(),
      ],
      verify: (bloc) {
        expect(bloc.state.canSubmit, isFalse);
        verifyChangeOnce();
        verify(() => repository.signOut()).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'preserves expected failure without logout and permits manual retry',
      build: () {
        var attempts = 0;
        stubChange(() async {
          if (++attempts == 1) throw AuthenticationException(errors: errors);
        });
        return ChangePasswordBloc(repository: repository);
      },
      act: (bloc) async {
        final failure = bloc.stream.firstWhere(
          (s) => s is ChangePasswordFailure,
        );
        bloc.add(submitted);
        await failure;
        expect(bloc.state.canSubmit, isTrue);
        verifyNever(() => repository.signOut());
        bloc.add(submitted);
      },
      expect: () => [
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordFailure>().having(
          (s) => s.errors,
          'errors',
          same(errors),
        ),
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSuccess>(),
      ],
      errors: () => isEmpty,
    );

    final unexpected = StateError('fixture');
    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'reports unexpected change failure with safe fallback',
      build: () {
        stubChange(() async => throw unexpected);
        return ChangePasswordBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordFailure>(),
      ],
      errors: () => [same(unexpected)],
      verify: (_) => verifyNever(() => repository.signOut()),
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'ignores logout retry before a password change',
      build: () => ChangePasswordBloc(repository: repository),
      act: (bloc) => bloc.add(retry),
      expect: () => [],
      verify: (_) => verifyZeroInteractions(repository),
    );
  });

  group('Local logout', () {
    final failure = StateError('fixture clear');
    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'retries only signOut after failure and never repeats PATCH',
      build: () {
        var attempts = 0;
        when(() => repository.signOut()).thenAnswer((_) async {
          if (++attempts == 1) throw failure;
        });
        return ChangePasswordBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (s) => s is ChangePasswordSignOutFailure,
        );
        bloc.add(submitted);
        await failed;
        expect(bloc.state.canSubmit, isFalse);
        expect(bloc.state.passwordChanged, isTrue);
        bloc
          ..add(submitted)
          ..add(retry);
      },
      expect: () => [
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSignOutFailure>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSuccess>(),
      ],
      errors: () => [same(failure)],
      verify: (_) {
        verifyChangeOnce();
        verify(() => repository.signOut()).called(2);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'repeated signOut failures keep only logout retry available',
      build: () {
        when(() => repository.signOut()).thenThrow(failure);
        return ChangePasswordBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere(
          (s) => s is ChangePasswordSignOutFailure,
        );
        bloc.add(submitted);
        await failed;
        bloc.add(retry);
      },
      expect: () => [
        isA<ChangePasswordSubmitting>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSignOutFailure>(),
        isA<ChangePasswordSigningOut>(),
        isA<ChangePasswordSignOutFailure>(),
      ],
      errors: () => [same(failure), same(failure)],
      verify: (bloc) {
        expect(bloc.state.canSubmit, isFalse);
        verifyChangeOnce();
      },
    );
  });

  group('Concurrency and lifecycle', () {
    test(
      'ignores a shared identity failure after closure without signing out',
      () async {
        final pending = Completer<void>();
        final started = Completer<void>();
        stubChange(() {
          started.complete();
          return pending.future;
        });
        final bloc = ChangePasswordBloc(repository: repository);
        final states = <ChangePasswordState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);

        bloc.add(submitted);
        await started.future;
        final closing = bloc.close();
        pending.completeError(const MissingAuthenticatedUserException());
        await closing;

        expect(states, [isA<ChangePasswordSubmitting>()]);
        verifyNever(repository.signOut);
      },
    );

    test(
      'drops submits and retries throughout pending PATCH and clear',
      () async {
        final patch = Completer<void>();
        final clear = Completer<void>();
        final clearing = Completer<void>();
        stubChange(() => patch.future);
        when(() => repository.signOut()).thenAnswer((_) {
          clearing.complete();
          return clear.future;
        });
        final bloc = ChangePasswordBloc(repository: repository);
        addTearDown(bloc.close);
        final started = bloc.stream.firstWhere(
          (s) => s is ChangePasswordSubmitting,
        );
        bloc.add(submitted);
        await started;
        bloc
          ..add(submitted)
          ..add(retry);
        patch.complete();
        await clearing.future;
        expect(bloc.state, isA<ChangePasswordSigningOut>());
        expect(bloc.state.canSubmit, isFalse);
        bloc
          ..add(submitted)
          ..add(retry);
        final success = bloc.stream.firstWhere(
          (s) => s is ChangePasswordSuccess,
        );
        clear.complete();
        await success;
        verifyChangeOnce();
        verify(() => repository.signOut()).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    for (final stage in ['patch', 'clear']) {
      for (final fails in [false, true]) {
        test(
          'closing during $stage with failure=$fails suppresses late states',
          () async {
            final pending = Completer<void>();
            if (stage == 'patch') {
              stubChange(() => pending.future);
            } else {
              when(() => repository.signOut())
                  .thenAnswer((_) => pending.future);
            }
            final bloc = ChangePasswordBloc(repository: repository);
            final reached = bloc.stream.firstWhere(
              (s) => stage == 'patch'
                  ? s is ChangePasswordSubmitting
                  : s is ChangePasswordSigningOut,
            );
            bloc.add(submitted);
            await reached;
            final previous = bloc.state;
            final closing = bloc.close();
            if (fails) {
              pending.completeError(StateError('fixture'));
            } else {
              pending.complete();
            }
            await closing;
            expect(bloc.state, same(previous));
            if (stage == 'patch') verifyNever(() => repository.signOut());
          },
        );
      }
    }
  });
}
