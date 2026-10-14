import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ExpensesFiltersWidget({
  super.key,
  final String? periodLabel,
  final String? categoryLabel,
  final VoidCallback? onRemovePeriod,
  final VoidCallback? onRemoveCategory,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      primary: false,
      child: Row(
        spacing: 8.0,
        children: [
          if (categoryLabel case final label?)
            _buildChip(
              context,
              label: label,
              onDeleted: onRemoveCategory,
              removalLabel: 'Remover filtro de categoria: $label',
            ),
          if (periodLabel case final label?)
            _buildChip(
              context,
              label: label,
              onDeleted: onRemovePeriod,
              removalLabel: 'Remover filtro de período: $label',
            ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required String removalLabel,
    required VoidCallback? onDeleted,
  }) {
    final foreground = onDeleted == null
        ? context.colors.onSurfaceVariant
        : context.colors.primary;

    final chip = InputChip(
      side: .none,
      onDeleted: onDeleted,
      visualDensity: .standard,
      deleteIconColor: foreground,
      isEnabled: onDeleted != null,
      materialTapTargetSize: .padded,
      deleteButtonTooltipMessage: removalLabel,
      disabledColor: context.colors.surfaceContainerHighest,
      deleteIcon: const IconWidget(icon: Icons.close, size: 18.0),
      backgroundColor: context.colors.primary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: context.radius.cornerRadius050,
      ),
      label: DefaultTextStyle(
        softWrap: false,
        overflow: .visible,
        style:
            context.typography.labelLarge?.copyWith(color: foreground) ??
            TextStyle(color: foreground),
        child: Text(label),
      ),
    );

    return onDeleted == null ? chip : BounceWidget.withoutOnPress(child: chip);
  }
}
