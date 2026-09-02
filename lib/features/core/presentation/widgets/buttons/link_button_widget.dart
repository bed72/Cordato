import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';

final class LinkButtonWidget extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const LinkButtonWidget({super.key, required this.label, required this.onTap});

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
