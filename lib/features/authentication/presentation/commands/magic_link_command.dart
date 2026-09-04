import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class MagicLinkCommand implements ICommand {
  final Command<String, void> send;

  MagicLinkCommand({required IAuthenticationRepository repository})
    : send = Command.createAsyncNoResult<String>((email) async {
        final data = await repository.requestMagicLink(email: email);
        data.fold((failure) => throw failure, (_) {});
      });

  @override
  void dispose() => send.dispose();
}
