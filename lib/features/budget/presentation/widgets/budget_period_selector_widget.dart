import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';

import 'package:cordato/features/budget/presentation/enums/budget_period_option_enum.dart';
import 'package:cordato/features/budget/presentation/mixins/budget_period_selector_widget_state_mixin.dart';

final class const BudgetPeriodSelectorWidget({
  super.key,
  required final DateTimeRange? period,
  required final BudgetPeriodOptionEnum selectedOption,
  required final ValueChanged<BudgetPeriodOptionEnum> onSelected,
  final String? failure,
}) extends StatefulWidget {
  @override
  State<BudgetPeriodSelectorWidget> createState() =>
      _BudgetPeriodSelectorWidgetState();
}

final class _BudgetPeriodSelectorWidgetState
    extends State<BudgetPeriodSelectorWidget>
    with BudgetPeriodSelectorWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8.0,
      crossAxisAlignment: .start,
      children: [
        Text(
          'Período',
          style: context.typography.bodyLarge?.copyWith(
            color: widget.failure == null
                ? context.colors.onSurfaceVariant
                : context.colors.error,
            fontWeight: .w500,
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final option in BudgetPeriodOptionEnum.values)
              buildOption(context, option),
          ],
        ),
        if (widget.period case final period?)
          Text(
            formatPeriod(period),
            style: context.typography.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        if (widget.failure case final failure?) buildFailure(context, failure),
      ],
    );
  }

  Widget buildOption(BuildContext context, BudgetPeriodOptionEnum option) {
    final selected = option == widget.selectedOption;

    return BounceWidget.withoutOnPress(
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => widget.onSelected(option),
        selectedColor: context.colors.primary,
        backgroundColor: context.colors.surface,
        side: BorderSide(
          color: selected ? context.colors.primary : context.colors.outline,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: context.radius.cornerRadius100,
        ),
        label: Text(
          option.label,
          style: context.typography.labelLarge?.copyWith(
            fontWeight: .w600,
            color: selected
                ? context.colors.onPrimary
                : context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget buildFailure(BuildContext context, String message) => Row(
    spacing: 6.0,
    children: [
      Icon(Icons.info_outline, size: 16.0, color: context.colors.error),
      Expanded(
        child: Text(
          message,
          style: context.typography.bodyMedium?.copyWith(
            color: context.colors.error,
          ),
        ),
      ),
    ],
  );
}
