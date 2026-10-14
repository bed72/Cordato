import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class DeleteUserCommand({required IUserRepository repository})
    implements ICommand {
  final Command<void, bool?> execute = Command.createAsyncNoParam<bool?>(
    () async => switch (await repository.delete()) {
      Right(:final value) => value,
      Left(:final value) => throw CommandFailureException(errors: value),
    },
    initialValue: null,
  );

  @override
  void dispose() => execute.dispose();
}
