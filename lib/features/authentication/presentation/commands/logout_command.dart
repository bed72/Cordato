import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class LogoutCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<void, LogoutRepositoryType?> execute =
      Command.createAsyncNoParam<LogoutRepositoryType?>(
        repository.logout,
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
