import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/settings/presentation/commands/logout_command.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  late LogoutCommand command;
  late IAuthenticationRepository repository;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    command = LogoutCommand(repository: repository);
  });

  tearDown(() => command.dispose());

  test('logs out through the authentication repository', () async {
    when(() => repository.signOut())
        .thenAnswer((_) async => const Right<Failure, void>(null));

    await command.signOut.runAsync();

    verify(() => repository.signOut()).called(1);
  });

  test('exposes logout failures as command errors', () async {
    const failure = LogoutFailure();
    when(() => repository.signOut())
        .thenAnswer((_) async => const Left<Failure, void>(failure));
    void onResult() {}

    command.signOut.results.addListener(onResult);
    await expectLater(command.signOut.runAsync(), throwsA(same(failure)));
    command.signOut.results.removeListener(onResult);
    verify(() => repository.signOut()).called(1);
  });

  test('disposes the logout command', () {
    expect(command.dispose, returnsNormally);
    command = LogoutCommand(repository: repository);
  });
}
