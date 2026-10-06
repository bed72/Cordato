import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class DeleteUserCommand({required IUserRepository repository})
    implements ICommand {
  final Command<void, DeleteRepositoryType?> execute =
      Command.createAsyncNoParam<DeleteRepositoryType?>(
        repository.delete,
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
