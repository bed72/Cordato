import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';

final class const LogoutBottomSheetWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const SizedBox(height: 18.0),
          OutlineButtonWidget(
            label: 'Voltar',
            onTap: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 12.0),
          ElevatedButtonWidget(
            label: 'Sair',
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
