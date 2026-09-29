import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/danger_button_widget.dart';

final class const SettingsLogoutWidget({
  super.key,
  required final VoidCallback onLogoutPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: .infinity,
      padding: const .only(top: 16.0),
      child: DangerButtonWidget(label: 'Sair', onTap: onLogoutPressed),
    );
  }
}
