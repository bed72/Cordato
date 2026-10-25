import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = SignUpSubmittedEvent(
    email: ' Person@Example.com ',
    password: ' secret ',
  );
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '409',
        detail: 'E-mail já cadastrado.',
        pointer: '/data/attributes/email',
        parameter: 'email',
      ),
    ],
  );
  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  void stub(Future<void> Function() answer) {
    when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  test('starts ready without requesting registration', () async {
    final bloc = SignUpBloc(repository: repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<SignUpInitial>());
    expect(bloc.state.canSubmit, isTrue);
    expect(bloc.state.isSubmitting, isFalse);
    verifyZeroInteractions(repository);
  });

  blocTest<SignUpBloc, SignUpState>(
    'delegates unchanged inputs and exposes only the confirmation email',
    build: () {
      stub(() async {});
      return SignUpBloc(repository: repository);
    },
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<SignUpSubmitting>()
          .having((state) => state.canSubmit, 'canSubmit', isFalse)
          .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
      isA<SignUpSuccess>()
          .having((state) => state.email, 'email', submitted.email)
          .having((state) => state.canSubmit, 'canSubmit', isFalse),
    ],
    verify: (_) {
      verify(
        () => repository.signUp(
          email: submitted.email,
          password: submitted.password,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  for (final failure in [errors, const ErrorsEntity(errors: [])]) {
    blocTest<SignUpBloc, SignUpState>(
      'preserves application errors including an empty collection: ${failure.errors.length}',
      build: () {
        stub(() async => throw AuthenticationException(errors: failure));
        return SignUpBloc(repository: repository);
      },
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<SignUpSubmitting>(),
        isA<SignUpFailure>()
            .having((state) => state.errors, 'errors', same(failure))
            .having((state) => state.canSubmit, 'canSubmit', isTrue),
      ],
      errors: () => isEmpty,
    );
  }

  final unexpected = StateError('private failure');
  blocTest<SignUpBloc, SignUpState>(
    'reports unexpected failures and uses safe feedback',
    build: () {
      stub(() async => throw unexpected);
      return SignUpBloc(repository: repository);
    },
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<SignUpSubmitting>(),
      isA<SignUpFailure>().having(
        (state) => state.errors.errors.single.title,
        'title',
        'Erro desconhecido',
      ),
    ],
    errors: () => [same(unexpected)],
  );

  blocTest<SignUpBloc, SignUpState>(
    'retries only manually and blocks submissions after success',
    build: () {
      var attempts = 0;
      stub(() async {
        if (++attempts == 1) throw AuthenticationException(errors: errors);
      });
      return SignUpBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere((state) => state is SignUpFailure);
      bloc.add(submitted);
      await failed;
      final finished = bloc.stream.firstWhere(
        (state) => state is SignUpSuccess,
      );
      bloc.add(submitted);
      await finished;
      bloc.add(submitted);
    },
    expect: () => [
      isA<SignUpSubmitting>(),
      isA<SignUpFailure>(),
      isA<SignUpSubmitting>(),
      isA<SignUpSuccess>(),
    ],
    verify: (_) => verify(
      () => repository.signUp(
        email: submitted.email,
        password: submitted.password,
      ),
    ).called(2),
  );

  test('drops duplicate and different submissions while pending', () async {
    final pending = Completer<void>();
    final started = Completer<void>();
    stub(() {
      started.complete();
      return pending.future;
    });
    final bloc = SignUpBloc(repository: repository);
    addTearDown(bloc.close);
    bloc.add(submitted);
    await started.future;
    bloc.add(submitted);
    bloc.add(
      const SignUpSubmittedEvent(email: 'other@example.com', password: 'other'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<SignUpSubmitting>());
    final finished = bloc.stream.firstWhere((state) => state is SignUpSuccess);
    pending.complete();
    await finished;
    await Future<void>.delayed(Duration.zero);
    verify(
      () => repository.signUp(
        email: submitted.email,
        password: submitted.password,
      ),
    ).called(1);
    verifyNoMoreInteractions(repository);
  });

  for (final outcome in ['success', 'expected failure', 'unexpected failure']) {
    test('closing prevents late states for $outcome', () async {
      final pending = Completer<void>();
      final started = Completer<void>();
      stub(() {
        started.complete();
        return pending.future;
      });
      final bloc = SignUpBloc(repository: repository);
      final states = <SignUpState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      addTearDown(bloc.close);
      bloc.add(submitted);
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
      expect(states, [isA<SignUpSubmitting>()]);
    });
  }

  test('screen instances do not share state', () async {
    stub(() async {});
    final first = SignUpBloc(repository: repository);
    final second = SignUpBloc(repository: repository);
    addTearDown(first.close);
    addTearDown(second.close);
    final finished = first.stream.firstWhere((state) => state is SignUpSuccess);
    first.add(submitted);
    await finished;
    expect(second.state, isA<SignUpInitial>());
    expect(second.state.canSubmit, isTrue);
  });
}
