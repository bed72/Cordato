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
  late DateTime now;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    now = DateTime(2026, 9, 7, 12);
    command = MagicLinkCommand(repository: repository, now: () => now);
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

  test('resends a magic link through the repository', () async {
    when(() => repository.requestMagicLink(email: email))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    await command.resend.runAsync(email);

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

  test('blocks resending for one minute after a successful resend', () {
    command.beginConfirmation(email);
    command.startCooldown();

    expect(command.email, email);
    expect(command.canResend, isFalse);
    expect(MagicLinkCommand.cooldown, const Duration(minutes: 1));
    expect(command.resendRemaining, const Duration(minutes: 1));

    now = now.add(const Duration(minutes: 1));

    expect(command.canResend, isTrue);
    expect(command.resendRemaining, Duration.zero);
  });

  test('blocks resending for one minute when a confirmation flow starts', () {
    command.beginConfirmation(email);

    expect(command.email, email);
    expect(command.canResend, isFalse);
    expect(MagicLinkCommand.cooldown, const Duration(minutes: 1));
    expect(command.resendRemaining, const Duration(minutes: 1));

    now = now.add(const Duration(minutes: 1));

    expect(command.canResend, isTrue);
    expect(command.resendRemaining, Duration.zero);
  });
}
