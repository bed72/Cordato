import 'package:command_it/command_it.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class SignUpCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<({String email, String password}), bool?> execute =
      Command.createAsync<({String email, String password}), bool?>((
        credentials,
      ) async {
        try {
          await repository.signUp(
            email: credentials.email,
            password: credentials.password,
          );
          return true;
        } on AuthenticationException catch (error) {
          throw CommandFailureException(errors: error.errors);
        }
      }, initialValue: null);

  @override
  void dispose() => execute.dispose();
}
