import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/settings/presentation/commands/logout_command.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';

final class const SettingsLogoutWidget({
  super.key,
  required final LogoutCommand command,
  required final VoidCallback onLogoutPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: .infinity,
      padding: const .only(top: 16.0),
      child: CommandBuilder<void, void>(
        command: command.signOut,
        whileRunning: (_, _, _) => const DangerButtonWidget(
          label: 'Sair',
          isLoading: true,
          onTap: null,
        ),
        onSuccess: (_, _) =>
            DangerButtonWidget(label: 'Sair', onTap: onLogoutPressed),
        onError: (_, _, _, _) =>
            DangerButtonWidget(label: 'Sair', onTap: onLogoutPressed),
      ),
    );
  }
}
