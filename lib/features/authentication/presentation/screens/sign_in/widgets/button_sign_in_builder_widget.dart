import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/commands/sign_in_command.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/button_sign_in_widget.dart';

final class const ButtonSignInBuilderWidget({
  super.key,
  required final SignInCommand command,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CommandBuilder<({String email, String password}), SessionEntity?>(
        command: command.execute,
        whileRunning: (_, _, _) =>
            const ButtonSignInWidget(isLoading: true, onPressed: null),
        onSuccess: (_, _) =>
            ButtonSignInWidget(isLoading: false, onPressed: onPressed),
        onError: (_, _, _, _) =>
            ButtonSignInWidget(isLoading: false, onPressed: onPressed),
      );
}
