import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';
import 'package:cordato/features/settings/presentation/widgets/logout_bottom_sheet_widget.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

mixin SettingsScreenStateMixin on State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.command.signOut.results.addListener(_handleLogout);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.command, widget.command)) return;

    oldWidget.command.signOut.results.removeListener(_handleLogout);
    widget.command.signOut.results.addListener(_handleLogout);
  }

  Future<void> showLogoutConfirmation() async {
    if (widget.command.signOut.results.value.isRunning) return;

    final confirmed = await showBottomSheetWidget<bool>(
      context: context,
      useSafeArea: false,
      title: 'Deseja sair?',
      subtitle: 'Você precisará entrar novamente para acessar sua conta.',
      child: const LogoutBottomSheetWidget(),
    );

    if (!mounted ||
        confirmed != true ||
        widget.command.signOut.results.value.isRunning) {
      return;
    }

    widget.command.signOut.run();
  }

  void _handleLogout() {
    final result = widget.command.signOut.results.value;
    if (!mounted || result.isRunning || !result.hasError) return;

    context.showToast(
      variant: .error,
      title: 'Não foi possível sair',
      description: result.error.toString(),
    );
  }

  @override
  void dispose() {
    widget.command.signOut.results.removeListener(_handleLogout);
    super.dispose();
  }
}
