import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';

final class const ActionButtonDashboardWidget({
  super.key,
  final VoidCallback? onBudget,
  final VoidCallback? onExpense,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ExpandableFab(
    distance: 56.0,
    elevation: 0.0,
    openButtonBuilder: RotateFloatingActionButtonBuilder(
      elevation: 0.0,
      shape: RoundedRectangleBorder(
        borderRadius: context.radius.cornerRadius100,
      ),
      child: BounceWidget.withoutOnPress(
        child: Container(
          width: 48.0,
          height: 48.0,
          alignment: Alignment.center,
          child: const IconWidget(size: 20.0, icon: Icons.menu),
        ),
      ),
    ),
    children: [
      Semantics(
        button: true,
        label: 'Adicionar gasto',
        enabled: onExpense != null,
        child: ExcludeSemantics(
          child: BounceWidget.withOnPress(
            onPress: onExpense,
            child: Container(
              width: 48.0,
              height: 48.0,
              alignment: .center,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: context.radius.cornerRadius100,
              ),
              child: IconWidget(
                size: 20.0,
                color: context.colors.onPrimary,
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ),
        ),
      ),
      Semantics(
        button: true,
        enabled: onBudget != null,
        label: 'Adicionar orçamento',
        child: ExcludeSemantics(
          child: BounceWidget.withOnPress(
            onPress: onBudget,
            child: Container(
              width: 48.0,
              height: 48.0,
              alignment: .center,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: context.radius.cornerRadius100,
              ),
              child: IconWidget(
                size: 20.0,
                icon: Icons.savings_outlined,
                color: context.colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
