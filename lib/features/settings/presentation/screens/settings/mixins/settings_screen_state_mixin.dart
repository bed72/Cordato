import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';
import 'package:cordato/features/settings/presentation/widgets/settings_logout_bottom_sheet_widget.dart';

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
    final confirmed = await showBottomSheetWidget<bool>(
      context: context,
      title: 'Realmente deseja sair?',
      child: const SettingsLogoutBottomSheetWidget(),
    );

    if (!mounted ||
        confirmed != true ||
        widget.command.execute.isRunning.value) {
      return;
    }
    widget.command.execute.run();
  }

  void _handleLogout() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning) return;

    if (data.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao sair',
        description: 'Não foi possível sair. Tente novamente.',
      );
      return;
    }

    if (data.data case Left(:final value)) {
      context.showToast(
        variant: .error,
        title: value.errors.first.title ?? 'Erro ao sair',
        description: value.errors
            .map(
              (error) =>
                  error.detail ?? 'Não foi possível sair. Tente novamente.',
            )
            .join('\n'),
      );
    }
  }
}
