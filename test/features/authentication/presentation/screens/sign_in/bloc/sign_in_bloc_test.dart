import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  const submitted = SignInSubmittedEvent(
    password: ' secret ',
    email: ' Person@Example.com ',
  );

  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '422',
        title: 'Validação',
        parameter: 'email',
        detail: 'E-mail inválido.',
        pointer: '/data/attributes/email',
      ),
      ErrorEntity(
        detail: 'Senha inválida.',
        pointer: '/data/attributes/password',
      ),
    ],
  );

  late AuthenticationRepositoryMock repository;

  setUp(() => repository = AuthenticationRepositoryMock());

  test('starts ready for input without querying the repository', () async {
    final bloc = SignInBloc(repository: repository);

    addTearDown(bloc.close);

    verifyZeroInteractions(repository);
    expect(bloc.state.canSubmit, isTrue);
    expect(bloc.state, isA<SignInInitial>());
    expect(bloc.state.isSubmitting, isFalse);
  });

  blocTest<SignInBloc, SignInState>(
    'submits unchanged credentials then publishes success',
    build: () {
      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) async {});

      return SignInBloc(repository: repository);
    },
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<SignInSubmitting>()
          .having((state) => state.canSubmit, 'canSubmit', isFalse)
          .having((state) => state.isSubmitting, 'isSubmitting', isTrue),
      isA<SignInSuccess>().having(
        (state) => state.canSubmit,
        'canSubmit',
        isFalse,
      ),
    ],
    verify: (_) {
      verify(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  blocTest<SignInBloc, SignInState>(
    'preserves the application errors instance without reporting a business failure',
    build: () {
      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) async => throw AuthenticationException(errors: errors));

      return SignInBloc(repository: repository);
    },
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<SignInSubmitting>(),
      isA<SignInFailure>()
          .having((state) => state.errors, 'errors', same(errors))
          .having((state) => state.canSubmit, 'canSubmit', isTrue),
    ],
    errors: () => isEmpty,
  );

  blocTest<SignInBloc, SignInState>(
    'preserves empty errors and accepts a manual retry',
    build: () {
      int attempts = 0;
      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) async {
        if (++attempts == 1) {
          throw AuthenticationException(errors: const ErrorsEntity(errors: []));
        }
      });

      return SignInBloc(repository: repository);
    },
    act: (bloc) async {
      final failed = bloc.stream.firstWhere((state) => state is SignInFailure);
      bloc.add(submitted);
      await failed;
      bloc.add(submitted);
    },
    expect: () => [
      isA<SignInSubmitting>(),
      isA<SignInFailure>().having(
        (state) => state.errors.errors,
        'errors',
        isEmpty,
      ),
      isA<SignInSubmitting>(),
      isA<SignInSuccess>(),
    ],
    verify: (_) => verify(
      () => repository.signIn(
        email: submitted.email,
        password: submitted.password,
      ),
    ).called(2),
  );

  final unexpected = StateError('unexpected repository error');
  blocTest<SignInBloc, SignInState>(
    'reports unexpected errors and publishes a safe retryable failure',
    build: () {
      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) async => throw unexpected);

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
          .having((state) => state.canSubmit, 'canSubmit', isTrue),
    ],
    errors: () => [same(unexpected)],
  );

  test(
    'drops duplicate and different credentials while submission is pending',
    () async {
      final pending = Completer<void>();

      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) => pending.future);

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

      bloc.add(submitted);
      bloc.add(
        const SignInSubmittedEvent(
          password: 'other',
          email: 'other@example.com',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<SignInSubmitting>());
      verify(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).called(1);

      final finished = bloc.stream.firstWhere(
        (state) => state is SignInSuccess,
      );

      pending.complete();

      await finished;
      await Future<void>.delayed(Duration.zero);
      expect(states, [isA<SignInSubmitting>(), isA<SignInSuccess>()]);
      verifyNoMoreInteractions(repository);
    },
  );

  blocTest<SignInBloc, SignInState>(
    'does not submit again after successful authentication',
    build: () {
      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) async {});

      return SignInBloc(repository: repository);
    },
    act: (bloc) async {
      final finished = bloc.stream.firstWhere(
        (state) => state is SignInSuccess,
      );
      bloc.add(submitted);
      await finished;
      bloc.add(submitted);
    },
    expect: () => [isA<SignInSubmitting>(), isA<SignInSuccess>()],
    verify: (_) => verify(
      () => repository.signIn(
        email: submitted.email,
        password: submitted.password,
      ),
    ).called(1),
  );

  for (final outcome in ['success', 'typed failure', 'unexpected failure']) {
    test('closing while $outcome is pending prevents late states', () async {
      final pending = Completer<void>();
      when(
        () => repository.signIn(
          email: submitted.email,
          password: submitted.password,
        ),
      ).thenAnswer((_) => pending.future);

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
          pending.complete();
        case 'typed failure':
          pending.completeError(AuthenticationException(errors: errors));
        default:
          pending.completeError(StateError('late error'));
      }

      await closing;
      expect(bloc.isClosed, isTrue);
      expect(states, [isA<SignInSubmitting>()]);
    });
  }

  test('keeps screen-owned instances independent', () async {
    when(
      () => repository.signIn(
        email: submitted.email,
        password: submitted.password,
      ),
    ).thenAnswer((_) async {});

    final first = SignInBloc(repository: repository);
    final second = SignInBloc(repository: repository);
    addTearDown(first.close);
    addTearDown(second.close);

    final finished = first.stream.firstWhere((state) => state is SignInSuccess);
    first.add(submitted);

    await finished;

    expect(second.state, isA<SignInInitial>());
    verify(
      () => repository.signIn(
        email: submitted.email,
        password: submitted.password,
      ),
    ).called(1);
  });
}
