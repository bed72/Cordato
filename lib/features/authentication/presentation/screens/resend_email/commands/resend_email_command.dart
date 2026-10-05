import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

final class ResendEmailCommand({required IAuthenticationRepository repository})
    implements ICommand {
  final Command<String, Either<ErrorsEntity, bool>?> execute =
      Command.createAsync<String, Either<ErrorsEntity, bool>?>(
        (email) => repository.resendEmail(email: email),
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
