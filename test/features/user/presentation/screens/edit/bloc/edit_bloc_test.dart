import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';

import '../../../../../../support/user/mocks/user_repository_mock.dart';

void main() {
  const event = EditSubmittedEvent(name: '  Nome original  ');
  const user = UserEntity(id: '1', name: 'API', email: 'person@example.com');
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '422',
        parameter: 'name',
        detail: 'Nome inválido',
        pointer: '/data/attributes/name',
      ),
      ErrorEntity(title: 'Outro erro'),
    ],
  );
  late UserRepositoryMock repository;
  setUp(() => repository = UserRepositoryMock());

  final unexpected = StateError('internal secret');

  group('Initial state and profile updates', () {
    test('starts available without automatic requests', () async {
      final bloc = EditBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<EditInitial>());
      expect(bloc.state.canSubmit, isTrue);
      expect(bloc.state.isSubmitting, isFalse);
      verifyZeroInteractions(repository);
    });

    blocTest<EditBloc, EditState>(
      'delegates the exact name, preserves the API entity and blocks after success',
      build: () {
        when(() => repository.update(name: event.name))
            .thenAnswer((_) async => user);
        return EditBloc(repository: repository);
      },
      act: (bloc) async {
        final finished = bloc.stream.firstWhere(
          (state) => state is EditSuccess,
        );
        bloc.add(event);
        await finished;
        bloc.add(const EditSubmittedEvent(name: 'Outro nome'));
      },
      expect: () => [
        isA<EditSubmitting>()
            .having((state) => state.canSubmit, 'canSubmit', isFalse)
            .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
        isA<EditSuccess>()
            .having((state) => state.user, 'user', same(user))
            .having((state) => state.canSubmit, 'canSubmit', isFalse),
      ],
      verify: (_) {
        verify(() => repository.update(name: event.name)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Failures and manual retry', () {
    const missingIdentity = MissingAuthenticatedUserException();

    blocTest<EditBloc, EditState>(
      'preserves shared identity errors without reporting',
      build: () {
        when(() => repository.update(name: event.name))
            .thenAnswer((_) async => throw missingIdentity);
        return EditBloc(repository: repository);
      },
      act: (bloc) => bloc.add(event),
      expect: () => [
        isA<EditSubmitting>(),
        isA<EditFailure>()
            .having(
              (state) => state.errors,
              'errors',
              same(missingIdentity.errors),
            )
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
      errors: () => isEmpty,
    );

    for (final failure in [errors, const ErrorsEntity(errors: [])]) {
      blocTest<EditBloc, EditState>(
        'preserves ${failure.errors.length} expected errors without reporting',
        build: () {
          when(() => repository.update(name: event.name))
              .thenAnswer((_) async => throw UserException(errors: failure));
          return EditBloc(repository: repository);
        },
        act: (bloc) => bloc.add(event),
        expect: () => [
          isA<EditSubmitting>(),
          isA<EditFailure>()
              .having((state) => state.errors, 'errors', same(failure))
              .having((state) => state.canSubmit, 'canSubmit', isTrue),
        ],
        errors: () => isEmpty,
      );
    }

    blocTest<EditBloc, EditState>(
      'reports unexpected failures with a safe fallback',
      build: () {
        when(() => repository.update(name: event.name))
            .thenAnswer((_) async => throw unexpected);
        return EditBloc(repository: repository);
      },
      act: (bloc) => bloc.add(event),
      expect: () => [
        isA<EditSubmitting>(),
        isA<EditFailure>().having(
          (state) => state.errors.errors.single.title,
          'title',
          'Erro desconhecido',
        ),
      ],
      errors: () => [same(unexpected)],
    );

    blocTest<EditBloc, EditState>(
      'allows retry only after another manual submission',
      build: () {
        var attempts = 0;
        when(() => repository.update(name: event.name)).thenAnswer((_) async {
          if (++attempts == 1) throw UserException(errors: errors);
          return user;
        });
        return EditBloc(repository: repository);
      },
      act: (bloc) async {
        final failed = bloc.stream.firstWhere((state) => state is EditFailure);
        bloc.add(event);
        await failed;
        verify(() => repository.update(name: event.name)).called(1);
        bloc.add(event);
      },
      expect: () => [
        isA<EditSubmitting>(),
        isA<EditFailure>(),
        isA<EditSubmitting>(),
        isA<EditSuccess>(),
      ],
      verify: (_) =>
          verify(() => repository.update(name: event.name)).called(1),
    );
  });

  group('Concurrency and lifecycle', () {
    test(
      'drops duplicate and different submissions during a pending update',
      () async {
        final pending = Completer<UserEntity>();
        final started = Completer<void>();
        when(() => repository.update(name: event.name)).thenAnswer((_) {
          started.complete();
          return pending.future;
        });
        final bloc = EditBloc(repository: repository);
        addTearDown(bloc.close);
        bloc.add(event);
        await started.future;
        bloc.add(event);
        bloc.add(const EditSubmittedEvent(name: 'Outro nome'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state, isA<EditSubmitting>());
        final finished = bloc.stream.firstWhere(
          (state) => state is EditSuccess,
        );
        pending.complete(user);
        await finished;
        await Future<void>.delayed(Duration.zero);
        verify(() => repository.update(name: event.name)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    for (final outcome in [
      'success',
      'expected failure',
      'missing identity',
      'unexpected failure',
    ]) {
      test(
        'closing ignores a pending $outcome without cancelling the operation',
        () async {
          final pending = Completer<UserEntity>();
          final started = Completer<void>();
          when(() => repository.update(name: event.name)).thenAnswer((_) {
            started.complete();
            return pending.future;
          });
          final bloc = EditBloc(repository: repository);
          final states = <EditState>[];
          final subscription = bloc.stream.listen(states.add);
          addTearDown(subscription.cancel);
          bloc.add(event);
          await started.future;
          final closing = bloc.close();
          switch (outcome) {
            case 'success':
              pending.complete(user);
            case 'expected failure':
              pending.completeError(UserException(errors: errors));
            case 'missing identity':
              pending.completeError(const MissingAuthenticatedUserException());
            default:
              pending.completeError(unexpected);
          }
          await closing;
          expect(states, [isA<EditSubmitting>()]);
          expect(bloc.isClosed, isTrue);
        },
      );
    }

    test('screen-owned instances have independent state', () async {
      when(() => repository.update(name: event.name))
          .thenAnswer((_) async => user);
      final first = EditBloc(repository: repository);
      final second = EditBloc(repository: repository);
      addTearDown(first.close);
      addTearDown(second.close);
      final finished = first.stream.firstWhere((state) => state is EditSuccess);
      first.add(event);
      await finished;
      expect(second.state, isA<EditInitial>());
    });
  });
}
