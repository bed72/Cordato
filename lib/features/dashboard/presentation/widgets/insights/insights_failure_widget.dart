import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';

final class const InsightsFailureWidget({
  super.key,
  required final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 20.0),
    child: Column(
      spacing: 8.0,
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        Text(
          'Não foi possível carregar os insights.',
          style: context.typography.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        TextButtonWidget(label: 'Tentar novamente', onTap: onRetry),
      ],
    ),
  );
}
