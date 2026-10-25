import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_state.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const requested = LogoutRequestedEvent();
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '403',
        title: 'Não autorizado',
        detail: 'Tente novamente.',
        pointer: '/status',
        parameter: 'status',
      ),
      ErrorEntity(detail: 'Outra falha'),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  test('starts ready without logging out automatically', () async {
    final bloc = LogoutBloc(repository: repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<LogoutInitial>());
    expect(bloc.state.canSubmit, isTrue);
    expect(bloc.state.isSubmitting, isFalse);
    verifyZeroInteractions(repository);
  });

  blocTest<LogoutBloc, LogoutState>(
    'waits for repository completion and blocks further logout after success',
    build: () {
      when(() => repository.logout()).thenAnswer((_) async {});
      return LogoutBloc(repository: repository);
    },
    act: (bloc) async {
      final finished = bloc.stream.firstWhere(
        (state) => state is LogoutSuccess,
      );
      bloc.add(requested);
      await finished;
      bloc.add(requested);
    },
    expect: () => [
      isA<LogoutSubmitting>()
          .having((state) => state.canSubmit, 'canSubmit', isFalse)
          .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
      isA<LogoutSuccess>()
          .having((state) => state.canSubmit, 'canSubmit', isFalse)
          .having((state) => state.isSubmitting, 'isSubmitting', isFalse),
    ],
    verify: (_) {
      verify(() => repository.logout()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  for (final failure in [errors, const ErrorsEntity(errors: [])]) {
    blocTest<LogoutBloc, LogoutState>(
      'preserves ${failure.errors.length} application errors without reporting them',
      build: () {
        when(() => repository.logout()).thenAnswer(
          (_) async => throw AuthenticationException(errors: failure),
        );
        return LogoutBloc(repository: repository);
      },
      act: (bloc) => bloc.add(requested),
      expect: () => [
        isA<LogoutSubmitting>(),
        isA<LogoutFailure>()
            .having((state) => state.errors, 'errors', same(failure))
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
      errors: () => isEmpty,
    );
  }

  final unexpected = StateError('private storage failure');
  blocTest<LogoutBloc, LogoutState>(
    'reports unexpected failure without exposing internal details',
    build: () {
      when(() => repository.logout()).thenAnswer((_) async => throw unexpected);
      return LogoutBloc(repository: repository);
    },
    act: (bloc) => bloc.add(requested),
    expect: () => [
      isA<LogoutSubmitting>(),
      isA<LogoutFailure>()
          .having(
            (state) => state.errors.errors.single.title,
            'title',
            'Erro desconhecido',
          )
          .having((state) => state.canSubmit, 'canSubmit', isTrue),
    ],
    errors: () => [same(unexpected)],
  );

  blocTest<LogoutBloc, LogoutState>(
    'allows only manual retry after failure',
    build: () {
      var attempts = 0;
      when(() => repository.logout()).thenAnswer((_) async {
        if (++attempts == 1) throw AuthenticationException(errors: errors);
      });
      return LogoutBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere((state) => state is LogoutFailure);
      bloc.add(requested);
      await failed;
      verify(() => repository.logout()).called(1);
      bloc.add(requested);
    },
    expect: () => [
      isA<LogoutSubmitting>(),
      isA<LogoutFailure>(),
      isA<LogoutSubmitting>(),
      isA<LogoutSuccess>(),
    ],
    verify: (_) => verify(() => repository.logout()).called(1),
  );

  test(
    'drops duplicate requests while pending rather than queueing them',
    () async {
      final pending = Completer<void>();
      final started = Completer<void>();
      when(() => repository.logout()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final bloc = LogoutBloc(repository: repository);
      addTearDown(bloc.close);
      bloc.add(requested);
      await started.future;
      bloc.add(requested);
      bloc.add(requested);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<LogoutSubmitting>());
      final finished = bloc.stream.firstWhere(
        (state) => state is LogoutSuccess,
      );
      pending.complete();
      await finished;
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.logout()).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  for (final outcome in ['success', 'expected failure', 'unexpected failure']) {
    test('closing ignores a pending $outcome', () async {
      final pending = Completer<void>();
      final started = Completer<void>();
      when(() => repository.logout()).thenAnswer((_) {
        started.complete();
        return pending.future;
      });
      final bloc = LogoutBloc(repository: repository);
      addTearDown(bloc.close);
      final states = <LogoutState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      bloc.add(requested);
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
      expect(states, [isA<LogoutSubmitting>()]);
    });
  }

  test('screen-owned instances do not share state', () async {
    when(() => repository.logout()).thenAnswer((_) async {});
    final first = LogoutBloc(repository: repository);
    final second = LogoutBloc(repository: repository);
    addTearDown(first.close);
    addTearDown(second.close);
    final finished = first.stream.firstWhere((state) => state is LogoutSuccess);
    first.add(requested);
    await finished;
    expect(second.state, isA<LogoutInitial>());
  });
}
