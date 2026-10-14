import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class SignUpCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<({String email, String password}), bool?> execute =
      Command.createAsync<({String email, String password}), bool?>((
        credentials,
      ) async {
        final data = await repository.signUp(
          email: credentials.email,
          password: credentials.password,
        );

        return switch (data) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        };
      }, initialValue: null);

  @override
  void dispose() => execute.dispose();
}
