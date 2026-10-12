import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ActionButtonDashboardWidget({
  super.key,
  final VoidCallback? onExpense,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BounceWidget.withoutOnPress(
      child: FloatingActionButton(
        elevation: 0.0,
        onPressed: onExpense,
        tooltip: 'Adicionar gasto',
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: context.radius.cornerRadius100,
        ),
        child: const IconWidget(size: 20.0, icon: Icons.receipt_long_outlined),
      ),
    );
  }
}
