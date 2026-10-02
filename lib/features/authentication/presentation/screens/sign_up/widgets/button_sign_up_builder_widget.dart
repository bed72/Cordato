import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/commands/sign_up_command.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/button_sign_up_widget.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class const ButtonSignUpBuilderWidget({
  super.key,
  required final SignUpCommand command,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CommandBuilder<
        ({String email, String password}),
        Either<ErrorsEntity, bool>?
      >(
        command: command.execute,
        whileRunning: (_, _, _) =>
            const ButtonSignUpWidget(isLoading: true, onPressed: null),
        onSuccess: (_, _) =>
            ButtonSignUpWidget(isLoading: false, onPressed: onPressed),
        onError: (_, _, _, _) =>
            ButtonSignUpWidget(isLoading: false, onPressed: onPressed),
      );
}
