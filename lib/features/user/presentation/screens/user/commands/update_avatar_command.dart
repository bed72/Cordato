import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class UpdateAvatarCommand({required IUserRepository repository})
    implements ICommand {
  final Command<String, UpdateRepositoryType?> execute =
      Command.createAsync<String, UpdateRepositoryType?>(
        initialValue: null,
        (seed) => repository.update(avatar: seed),
      );

  @override
  void dispose() => execute.dispose();
}
