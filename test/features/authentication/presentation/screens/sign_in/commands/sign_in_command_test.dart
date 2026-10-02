import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/commands/sign_in_command.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  const credentials = (email: 'person@example.com', password: 'secret');

  late IAuthenticationRepository repository;
  late SignInCommand command;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    command = SignInCommand(repository: repository);
  });

  tearDown(() => command.dispose());

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

    final result = await command.execute.runAsync(credentials);

    expect(result?.right, same(session));
    expect(command.execute.value?.right, same(session));
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
        ErrorEntity(detail: 'E-mail inválido.', pointer: '/email'),
        ErrorEntity(detail: 'Senha inválida.', pointer: '/password'),
      ],
    );
    when(
      () => repository.signIn(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync(credentials);

    expect(result?.left, same(errors));
    expect(result?.left.errors, hasLength(2));
    expect(command.execute.value?.left, same(errors));
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
      } finally {
        command.execute.results.removeListener(onResult);
      }
    },
  );
}
