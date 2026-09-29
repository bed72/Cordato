import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/sign_up_command.dart';
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
  });
}
