import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class SignUpCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<({String email, String password}), Either<ErrorsEntity, bool>?>
  execute =
      Command.createAsync<
        ({String email, String password}),
        Either<ErrorsEntity, bool>?
      >(
        (credentials) => repository.signUp(
          email: credentials.email,
          password: credentials.password,
        ),
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
