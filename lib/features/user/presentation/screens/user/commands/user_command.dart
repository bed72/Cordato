import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class UserCommand({required IUserRepository repository})
    implements ICommand {
  final Command<void, GetByIdRepositoryType?> execute =
      Command.createAsyncNoParam<GetByIdRepositoryType?>(
        repository.getById,
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
