import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/widgets/button_magic_link_widget.dart';

final class ButtonMagicLinkBuilderWidget extends StatelessWidget {
  final MagicLinkCommand command;
  final VoidCallback onPressed;

  const ButtonMagicLinkBuilderWidget({
    super.key,
    required this.command,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => CommandBuilder<String, void>(
    command: command.send,
    whileRunning: (_, _, _) =>
        const ButtonMagicLinkWidget(isLoading: true, onPressed: null),
    onSuccess: (_, _) =>
        ButtonMagicLinkWidget(isLoading: false, onPressed: onPressed),
    onError: (_, _, _, _) =>
        ButtonMagicLinkWidget(isLoading: false, onPressed: onPressed),
  );
}
