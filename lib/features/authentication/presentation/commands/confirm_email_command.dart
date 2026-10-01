import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/authentication/domain/enums/email_verification_status_enum.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class ConfirmEmailCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<String, EmailVerificationStatusEnum?> execute =
      Command.createAsync<String, EmailVerificationStatusEnum?>(
        (url) => repository.confirmEmail(url),
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
