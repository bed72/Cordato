import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/confirmation_code_command.dart';
import 'package:cordato/features/core/domain/either.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  const email = 'person@example.com';
  const code = '123456';

  late IAuthenticationRepository repository;
  late ConfirmationCodeCommand command;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    command = ConfirmationCodeCommand(repository: repository);
  });

  tearDown(() {
    command.dispose();
  });

  test('confirms a code through the repository', () async {
    when(() => repository.confirmCode(email: email, code: code))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    await command.confirm.runAsync((email: email, code: code));

    verify(() => repository.confirmCode(email: email, code: code)).called(1);
  });

  test('exposes confirmation failures as command errors', () async {
    when(() => repository.confirmCode(email: email, code: code)).thenAnswer(
      (_) async => const Left<Failure, void>(MagicLinkConfirmationFailure()),
    );

    void onResult() {}

    command.confirm.results.addListener(onResult);
    await expectLater(
      command.confirm.runAsync((email: email, code: code)),
      throwsA(isA<MagicLinkConfirmationFailure>()),
    );
    command.confirm.results.removeListener(onResult);
  });

  test('disposes the confirmation command', () {
    expect(command.dispose, returnsNormally);
    command = ConfirmationCodeCommand(repository: repository);
  });
}
