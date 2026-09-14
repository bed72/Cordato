import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/settings/presentation/commands/logout_command.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';

final class SettingsLogoutWidget extends StatelessWidget {
  final LogoutCommand command;
  final VoidCallback onLogoutPressed;

  const SettingsLogoutWidget({
    super.key,
    required this.command,
    required this.onLogoutPressed,
  });

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
