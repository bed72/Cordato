import 'package:command_it/command_it.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';

final class ConfirmationCodeCommand implements ICommand {
  final Command<({String email, String code}), void> confirm;

  ConfirmationCodeCommand({required IAuthenticationRepository repository})
    : confirm = Command.createAsyncNoResult<({String email, String code})>((
        data,
      ) async {
        final response = await repository.confirmCode(
          code: data.code,
          email: data.email,
        );

        response.fold((failure) => throw failure, (_) {});
      });

  @override
  void dispose() => confirm.dispose();
}
