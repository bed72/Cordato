import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';

import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';

mixin SettingsScreenStateMixin on State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.command.execute.results.addListener(_handleLogout);
  }

  @override
  void dispose() {
    widget.command.execute.results.removeListener(_handleLogout);
    super.dispose();
  }

  Future<void> showLogoutConfirmation() async {
    if (widget.command.execute.isRunning.value) return;
    await showConfirmationBottomSheetWidget(
      context: context,
      title: 'Realmente deseja sair?',
      subtitle: 'Ao sair da sua conta, você precisará fazer login novamente para acessar o Trocado.',
      confirmLabel: 'Sair',
      onConfirm: () {
        if (widget.command.execute.isRunning.value) return;
        widget.command.execute.run();
      },
    );
  }

  void _handleLogout() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning) return;

    if (!data.hasError) return;
    if (data.error case CommandFailureException(:final errors)
        when errors.errors.isNotEmpty) {
      context.showToast(
        variant: .error,
        title: errors.errors.first.title ?? 'Erro ao sair',
        description: errors.errors
            .map(
              (error) =>
                  error.detail ?? 'Não foi possível sair. Tente novamente.',
            )
            .join('\n'),
      );
      return;
    }
    context.showToast(
      variant: .error,
      title: 'Erro ao sair',
      description: 'Não foi possível sair. Tente novamente.',
    );
  }
}
