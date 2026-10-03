import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

final class const SettingsLogoutBottomSheetWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(
        spacing: 16.0,
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            'Ao sair da sua conta, você precisará fazer login novamente para acessar o Trocado.',
            maxLines: 2,
            style: context.typography.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          OutlineButtonWidget(
            label: 'Voltar',
            onTap: () => Navigator.of(context).pop(false),
          ),
          ElevatedButtonWidget(
            label: 'Sair',
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
