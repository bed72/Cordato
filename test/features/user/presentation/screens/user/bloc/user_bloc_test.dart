import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_event.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_state.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  const user = UserEntity(
    id: '1',
    name: 'Pessoa',
    email: 'person@example.com',
    status: 'active',
  );
  const saved = UserEntity(
    id: '1',
    name: 'API',
    email: 'person@example.com',
    status: 'active',
    avatar: '  seed  ',
  );
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '422',
        detail: 'Inválido',
        pointer: '/data/attributes/avatar',
        parameter: 'avatar',
      ),
      ErrorEntity(title: 'Outro erro'),
    ],
  );
  const load = UserRequestedEvent();
  const avatar = UserAvatarSubmittedEvent(seed: '  seed  ');
  const delete = UserDeleteRequestedEvent();
  late UserRepositoryMock repository;

  setUp(() {
    repository = UserRepositoryMock();
    when(() => repository.getById()).thenAnswer((_) async => user);
    when(() => repository.update(avatar: avatar.seed))
        .thenAnswer((_) async => saved);
    when(() => repository.delete()).thenAnswer((_) async {});
  });

  group('Profile loading and avatar updates', () {
    test('starts idle without loading automatically', () async {
      final bloc = UserBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<UserInitial>());
      expect(bloc.state.canEdit, isFalse);
      verifyZeroInteractions(repository);
    });

    blocTest<UserBloc, UserState>(
      'loads the current profile',
      build: () => UserBloc(repository: repository),
      act: (bloc) => bloc.add(load),
      expect: () => [
        isA<UserLoading>().having((state) => state.isBusy, 'isBusy', isTrue),
        isA<UserReady>().having((state) => state.user, 'user', same(user)),
      ],
      verify: (_) => verify(() => repository.getById()).called(1),
    );

    blocTest<UserBloc, UserState>(
      'does not save an avatar without a loaded profile',
      build: () => UserBloc(repository: repository),
      act: (bloc) => bloc.add(avatar),
      expect: () => [],
      verify: (_) => verifyZeroInteractions(repository),
    );

    blocTest<UserBloc, UserState>(
      'delegates the seed unchanged and publishes the API profile',
      build: () => UserBloc(repository: repository),
      seed: () => const UserReady(data: user),
      act: (bloc) => bloc.add(avatar),
      expect: () => [
        isA<UserAvatarSaving>()
            .having((state) => state.user, 'user', same(user))
            .having((state) => state.canEdit, 'canEdit', isFalse),
        isA<UserAvatarSuccess>().having(
          (state) => state.user,
          'user',
          same(saved),
        ),
      ],
      verify: (_) =>
          verify(() => repository.update(avatar: avatar.seed)).called(1),
    );

    blocTest<UserBloc, UserState>(
      'does not confirm an avatar the API did not save',
      build: () {
        when(() => repository.update(avatar: avatar.seed))
            .thenAnswer((_) async => user);
        return UserBloc(repository: repository);
      },
      seed: () => const UserReady(data: user),
      act: (bloc) => bloc.add(avatar),
      expect: () => [
        isA<UserAvatarSaving>(),
        isA<UserAvatarFailure>().having(
          (state) => state.user,
          'user',
          same(user),
        ),
      ],
      errors: () => isEmpty,
    );
  });

  group('Account deletion', () {
    blocTest<UserBloc, UserState>(
      'confirmed deletion blocks every subsequent operation',
      build: () => UserBloc(repository: repository),
      seed: () => const UserReady(data: user),
      act: (bloc) async {
        final finished = bloc.stream.firstWhere(
          (state) => state is UserDeleteSuccess,
        );
        bloc.add(delete);
        await finished;
        bloc.add(delete);
        bloc.add(load);
        bloc.add(avatar);
      },
      expect: () => [
        isA<UserDeleting>().having(
          (state) => state.canDelete,
          'canDelete',
          isFalse,
        ),
        isA<UserDeleteSuccess>().having(
          (state) => state.canLoad,
          'canLoad',
          isFalse,
        ),
      ],
      verify: (_) {
        verify(() => repository.delete()).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<UserBloc, UserState>(
      'rejected deletion preserves profile and allows manual retry',
      build: () {
        when(() => repository.delete())
            .thenAnswer((_) async => throw UserException(errors: errors));
        return UserBloc(repository: repository);
      },
      seed: () => const UserReady(data: user),
      act: (bloc) => bloc.add(delete),
      expect: () => [
        isA<UserDeleting>(),
        isA<UserDeleteFailure>()
            .having((state) => state.user, 'user', same(user))
            .having((state) => state.canDelete, 'canDelete', isTrue),
      ],
      errors: () => isEmpty,
    );
  });

  group('Shared failures, concurrency and lifecycle', () {
    for (final event in [load, avatar, delete]) {
      Future<dynamic> request() => switch (event) {
        UserRequestedEvent() => repository.getById(),
        UserAvatarSubmittedEvent() => repository.update(avatar: avatar.seed),
        _ => repository.delete(),
      };
      void stub(Future<Object?> Function() answer) {
        switch (event) {
          case UserRequestedEvent():
            when(() => repository.getById())
                .thenAnswer((_) async => await answer() as UserEntity);
          case UserAvatarSubmittedEvent():
            when(() => repository.update(avatar: avatar.seed))
                .thenAnswer((_) async => await answer() as UserEntity);
          case UserDeleteRequestedEvent():
            when(() => repository.delete()).thenAnswer((_) async {
              await answer();
            });
        }
      }

      Matcher submitting() => switch (event) {
        UserRequestedEvent() => isA<UserLoading>(),
        UserAvatarSubmittedEvent() => isA<UserAvatarSaving>(),
        _ => isA<UserDeleting>(),
      };
      Matcher failure(ErrorsEntity? expected) => switch (event) {
        UserRequestedEvent() => isA<UserFailure>().having(
          (state) => state.errors,
          'errors',
          expected == null ? isA<ErrorsEntity>() : same(expected),
        ),
        UserAvatarSubmittedEvent() => isA<UserAvatarFailure>().having(
          (state) => state.errors,
          'errors',
          expected == null ? isA<ErrorsEntity>() : same(expected),
        ),
        _ => isA<UserDeleteFailure>().having(
          (state) => state.errors,
          'errors',
          expected == null ? isA<ErrorsEntity>() : same(expected),
        ),
      };
      Object? result() => event is UserDeleteRequestedEvent ? null : saved;

      for (final rejected in [errors, const ErrorsEntity(errors: [])]) {
        blocTest<UserBloc, UserState>(
          '${event.runtimeType} preserves ${rejected.errors.length} errors without reporting',
          build: () {
            stub(() async => throw UserException(errors: rejected));
            return UserBloc(repository: repository);
          },
          seed: () => const UserReady(data: user),
          act: (bloc) => bloc.add(event),
          expect: () => [submitting(), failure(rejected)],
          errors: () => isEmpty,
        );
      }

      final unexpected = StateError('internal secret');
      blocTest<UserBloc, UserState>(
        '${event.runtimeType} reports unexpected failure with safe fallback',
        build: () {
          stub(() async => throw unexpected);
          return UserBloc(repository: repository);
        },
        seed: () => const UserReady(data: user),
        act: (bloc) => bloc.add(event),
        expect: () => [submitting(), failure(null)],
        errors: () => [same(unexpected)],
      );

      blocTest<UserBloc, UserState>(
        '${event.runtimeType} retries only after another manual request',
        build: () {
          var attempts = 0;
          stub(() async {
            if (++attempts == 1) throw UserException(errors: errors);
            return result();
          });
          return UserBloc(repository: repository);
        },
        seed: () => const UserReady(data: user),
        act: (bloc) async {
          final failed = bloc.stream.firstWhere(
            (state) => failure(errors).matches(state, {}),
          );
          bloc.add(event);
          await failed;
          verify(request).called(1);
          bloc.add(event);
        },
        expect: () => [
          submitting(),
          failure(errors),
          submitting(),
          isA<UserState>().having((state) => state.isBusy, 'isBusy', isFalse),
        ],
        verify: (_) => verify(request).called(1),
      );

      test(
        '${event.runtimeType} drops all duplicate and competing operations while pending',
        () async {
          final started = Completer<void>();
          final pending = Completer<Object?>();
          stub(() {
            started.complete();
            return pending.future;
          });
          final bloc = UserBloc(repository: repository);
          addTearDown(bloc.close);
          if (event is UserAvatarSubmittedEvent) {
            final ready = bloc.stream.firstWhere((state) => state is UserReady);
            bloc.add(load);
            await ready;
            clearInteractions(repository);
          }
          bloc.add(event);
          await started.future;
          bloc.add(load);
          bloc.add(avatar);
          bloc.add(delete);
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.isBusy, isTrue);
          final finished = bloc.stream.firstWhere((state) => !state.isBusy);
          pending.complete(result());
          await finished;
          await Future<void>.delayed(Duration.zero);
          verify(request).called(1);
          verifyNoMoreInteractions(repository);
        },
      );

      for (final outcome in ['success', 'expected', 'unexpected']) {
        test(
          '${event.runtimeType} ignores late $outcome after closing',
          () async {
            final started = Completer<void>();
            final pending = Completer<Object?>();
            stub(() {
              started.complete();
              return pending.future;
            });
            final bloc = UserBloc(repository: repository);
            if (event is UserAvatarSubmittedEvent) {
              final ready = bloc.stream.firstWhere(
                (state) => state is UserReady,
              );
              bloc.add(load);
              await ready;
            }
            final states = <UserState>[];
            final subscription = bloc.stream.listen(states.add);
            addTearDown(subscription.cancel);
            bloc.add(event);
            await started.future;
            final closing = bloc.close();
            switch (outcome) {
              case 'success':
                pending.complete(result());
              case 'expected':
                pending.completeError(UserException(errors: errors));
              default:
                pending.completeError(unexpected);
            }
            await closing;
            expect(states, [submitting()]);
            expect(bloc.isClosed, isTrue);
          },
        );
      }
    }
  });

  group('Independent owners', () {
    test('independent instances do not share loaded data', () async {
      final first = UserBloc(repository: repository);
      final second = UserBloc(repository: repository);
      addTearDown(first.close);
      addTearDown(second.close);
      final ready = first.stream.firstWhere((state) => state is UserReady);
      first.add(load);
      await ready;
      expect(second.state, isA<UserInitial>());
    });
  });
}
