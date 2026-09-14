import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';

final class SettingsLogoutWidget extends StatelessWidget {
  final VoidCallback? onLogoutPressed;

  const SettingsLogoutWidget({super.key, required this.onLogoutPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: .infinity,
      padding: const .only(top: 16.0),
      child: DangerButtonWidget(label: 'Sair', onTap: onLogoutPressed),
    );
  }
}
