import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/resend_email_verification_command.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  const email = 'person@example.com';
  late IAuthenticationRepository repository;
  late ResendEmailVerificationCommand command;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    command = ResendEmailVerificationCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('resend passes the email and returns acceptance', () async {
    when(() => repository.resendEmailVerification(email: email))
        .thenAnswer((_) async => const Right(true));

    final result = await command.execute.runAsync(email);

    expect(result?.right, isTrue);
    verify(() => repository.resendEmailVerification(email: email)).called(1);
  });

  test('resend keeps API errors in the command result', () async {
    const errors = ErrorsEntity(
      errors: [ErrorEntity(detail: 'Aguarde antes de reenviar.')],
    );
    when(() => repository.resendEmailVerification(email: email))
        .thenAnswer((_) async => const Left(errors));

    final result = await command.execute.runAsync(email);

    expect(result?.left, same(errors));
  });
}
