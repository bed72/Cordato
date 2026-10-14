import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/commands/sign_in_command.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import '../../../../../../support/authentication/mocks/authentication_repository_mock.dart';

void main() {
  void onResult() {}
  const credentials = (email: 'person@example.com', password: 'secret');

  late IAuthenticationRepository repository;
  late SignInCommand command;

  setUp(() {
    repository = AuthenticationRepositoryMock();
    command = SignInCommand(repository: repository);
    command.execute.results.addListener(onResult);
  });

  tearDown(() {
    command.execute.results.removeListener(onResult);
    command.dispose();
  });

  test('starts without a session or a repository call', () {
    expect(command.execute.value, isNull);
    expect(command.execute.results.value.hasError, isFalse);
    verifyZeroInteractions(repository);
  });

  test('sign-in returns the session from the repository', () async {
    final session = SessionEntity(
      token: 'example-token',
      userId: 'user-1',
      expiresAt: DateTime.utc(2026, 9, 28),
    );
    when(
      () => repository.signIn(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => Right(session));

    final data = await command.execute.runAsync(credentials);

    expect(data, same(session));
    expect(command.execute.value, same(session));
    expect(command.execute.results.value.data, same(session));
    expect(command.execute.results.value.paramData, credentials);
    verify(
      () => repository.signIn(
        email: credentials.email,
        password: credentials.password,
      ),
    ).called(1);
  });

  test('sign-in preserves all errors in the command result', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          title: 'Validação',
          status: '422',
          detail: 'E-mail inválido.',
          pointer: '/data/attributes/email',
          parameter: 'email',
        ),
        ErrorEntity(detail: 'Senha inválida.', pointer: '/password'),
      ],
    );
    when(
      () => repository.signIn(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Left(errors));

    await expectLater(
      command.execute.runAsync(credentials),
      throwsA(
        isA<CommandFailureException>().having(
          (failure) => failure.errors,
          'errors',
          same(errors),
        ),
      ),
    );
    final failure =
        command.execute.results.value.error as CommandFailureException;
    expect(failure.errors, same(errors));
    expect(command.execute.results.value.hasError, isTrue);
    expect(command.execute.errors.value?.error, same(failure));
    expect(command.execute.value, isNull);
  });

  test(
    'exposes an unexpected repository exception as a command error',
    () async {
      final failure = StateError('repository unavailable');
      when(
        () => repository.signIn(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => throw failure);

      void onResult() {}

      command.execute.results.addListener(onResult);
      try {
        await expectLater(
          command.execute.runAsync(credentials),
          throwsA(same(failure)),
        );
        expect(command.execute.results.value.error, same(failure));
        expect(command.execute.errors.value?.error, same(failure));
      } finally {
        command.execute.results.removeListener(onResult);
      }
    },
  );

  test(
    'keeps empty failure distinct from a previous session and allows retry',
    () async {
      final session = SessionEntity(
        token: 'example-token',
        userId: 'user-1',
        expiresAt: DateTime.utc(2026, 9, 28),
      );
      when(
        () => repository.signIn(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => Right(session));
      await command.execute.runAsync(credentials);

      const errors = ErrorsEntity(errors: []);
      when(
        () => repository.signIn(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => const Left(errors));
      await expectLater(
        command.execute.runAsync(credentials),
        throwsA(
          isA<CommandFailureException>().having(
            (failure) => failure.errors,
            'errors',
            same(errors),
          ),
        ),
      );
      expect(command.execute.value, same(session));
      expect(command.execute.results.value.data, isNull);
      expect(command.execute.results.value.hasError, isTrue);

      when(
        () => repository.signIn(
          email: credentials.email,
          password: credentials.password,
        ),
      ).thenAnswer((_) async => Right(session));
      expect(await command.execute.runAsync(credentials), same(session));
      expect(command.execute.results.value.hasError, isFalse);
      verify(
        () => repository.signIn(
          email: credentials.email,
          password: credentials.password,
        ),
      ).called(3);
    },
  );

  test('delegates credentials without normalization', () async {
    const input = (email: '  Person@Example.com  ', password: ' secret ');
    final session = SessionEntity(
      token: 'token',
      userId: 'user',
      expiresAt: DateTime(2026),
    );
    when(() => repository.signIn(email: input.email, password: input.password))
        .thenAnswer((_) async => Right(session));
    expect(await command.execute.runAsync(input), same(session));
    verify(
      () => repository.signIn(email: input.email, password: input.password),
    ).called(1);
  });
}
