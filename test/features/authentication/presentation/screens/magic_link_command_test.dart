import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/core/domain/either.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  const email = 'person@example.com';

  late IAuthenticationRepository repository;
  late MagicLinkCommand command;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    command = MagicLinkCommand(repository: repository);
  });

  tearDown(() {
    command.dispose();
  });

  test('requests a magic link through the repository', () async {
    when(() => repository.requestMagicLink(email: email))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    await command.send.runAsync(email);

    verify(() => repository.requestMagicLink(email: email)).called(1);
  });

  test('exposes repository failures as command errors', () async {
    when(() => repository.requestMagicLink(email: email)).thenAnswer(
      (_) async => const Left<Failure, void>(MagicLinkRequestFailure()),
    );

    void onResult() {}

    command.send.results.addListener(onResult);
    await expectLater(
      command.send.runAsync(email),
      throwsA(isA<MagicLinkRequestFailure>()),
    );
    command.send.results.removeListener(onResult);
  });
}
