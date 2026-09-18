import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';

final class const LinkButtonWidget({
  super.key,
  required final String label,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButtonWidget(
      onTap: onTap,
      child: Text(
        label,
        style: (context.typography.bodySmall)?.copyWith(
          decoration: .underline,
          color: context.colors.primary,
          decorationColor: context.colors.primary,
        ),
      ),
    );
  }
}
