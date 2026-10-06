import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_widget.dart';

Future<void> showConfirmationBottomSheetWidget({
  required BuildContext context,
  required String title,
  required String subtitle,
  required VoidCallback onConfirm,
  String confirmLabel = 'Confirmar',
}) async {
  final confirmed = await showBottomSheetWidget<bool>(
    context: context,
    title: title,
    subtitle: subtitle,
    child: ConfirmationBottomSheetWidget(confirmLabel: confirmLabel),
  );

  if (!context.mounted || confirmed != true) return;
  onConfirm();
}

final class const ConfirmationBottomSheetWidget({
  super.key,
  final String confirmLabel = 'Confirmar',
}) extends StatelessWidget {
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
          const SizedBox.shrink(),
          OutlineButtonWidget(
            label: 'Voltar',
            onTap: () => Navigator.of(context).pop(false),
          ),
          ElevatedButtonWidget(
            label: confirmLabel,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
