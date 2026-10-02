import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';

final class GetUserNameCommand({required IUserRepository repository})
    implements ICommand {
  final Command<void, String?> execute = Command.createAsyncNoParam<String?>(
    repository.getUserName,
    initialValue: null,
  );

  @override
  void dispose() => execute.dispose();
}
