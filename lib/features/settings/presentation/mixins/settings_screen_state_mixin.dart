import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';
import 'package:cordato/features/settings/presentation/widgets/logout_bottom_sheet_widget.dart';

import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

mixin SettingsScreenStateMixin on State<SettingsScreen> {
  Future<void> showLogoutConfirmation() async {
    final confirmed = await showBottomSheetWidget<bool>(
      context: context,
      useSafeArea: false,
      title: 'Deseja sair?',
      subtitle: 'Você precisará entrar novamente para acessar sua conta.',
      child: const LogoutBottomSheetWidget(),
    );

    if (!mounted || confirmed != true) return;
    widget.onLogoutPressed?.call();
  }
}
