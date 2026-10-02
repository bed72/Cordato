import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/commands/sign_up_command.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  const credentials = (email: 'person@example.com', password: 'secret');

  late IAuthenticationRepository repository;
  late SignUpCommand command;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    command = SignUpCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('sign-up returns the registration result', () async {
    when(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Right(true));

    final result = await command.execute.runAsync(credentials);

    expect(result?.right, isTrue);
    expect(command.execute.value?.right, isTrue);
    verify(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).called(1);
  });

  test('sign-up preserves the error list in the command result', () async {
    const errors = ErrorsEntity(
      errors: [ErrorEntity(detail: 'E-mail já cadastrado.')],
    );
    when(
      () => repository.signUp(
        email: credentials.email,
        password: credentials.password,
      ),
    ).thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync(credentials);

    expect(result?.left, same(errors));
    expect(command.execute.value?.left, same(errors));
  });

  test(
    'exposes an unexpected repository exception as a command error',
    () async {
      final failure = StateError('repository unavailable');
      when(
        () => repository.signUp(
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
