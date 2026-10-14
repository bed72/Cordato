import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class LogoutCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<void, bool?> execute = Command.createAsyncNoParam<bool?>(
    () async {
      final data = await repository.logout();

      return switch (data) {
        Right(:final value) => value,
        Left(:final value) => throw CommandFailureException(errors: value),
      };
    },
    initialValue: null,
  );

  @override
  void dispose() => execute.dispose();
}
