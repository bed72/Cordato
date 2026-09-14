import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class LogoutCommand implements ICommand {
  final Command<void, void> signOut;

  LogoutCommand({required IAuthenticationRepository repository})
    : signOut = Command.createAsyncNoParamNoResult(() async {
        final data = await repository.signOut();
        data.fold((failure) => throw failure, (_) {});
      });

  @override
  void dispose() => signOut.dispose();
}
