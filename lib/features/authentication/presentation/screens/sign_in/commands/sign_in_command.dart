import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class SignInCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<({String email, String password}), SessionEntity?> execute =
      Command.createAsync<({String email, String password}), SessionEntity?>(
        initialValue: null,
        (credentials) async {
          final data = await repository.signIn(
            email: credentials.email,
            password: credentials.password,
          );

          return switch (data) {
            Right(:final value) => value,
            Left(:final value) => throw CommandFailureException(errors: value),
          };
        },
      );

  @override
  void dispose() => execute.dispose();
}
