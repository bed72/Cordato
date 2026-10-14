import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class UpdateUserCommand({required IUserRepository repository})
    implements ICommand {
  final Command<String, UserEntity?> execute =
      Command.createAsync<String, UserEntity?>(
        initialValue: null,
        (name) async => switch (await repository.update(name: name)) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        },
      );

  @override
  void dispose() => execute.dispose();
}
