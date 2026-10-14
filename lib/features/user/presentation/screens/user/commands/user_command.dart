import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class UserCommand({required IUserRepository repository})
    implements ICommand {
  final Command<void, UserEntity?> execute =
      Command.createAsyncNoParam<UserEntity?>(
        () async => switch (await repository.getById()) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        },
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
