import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class const DashboardMonthSelectorWidget({
  super.key,
  required final DateTime selectedMonth,
  required final IDateFormatter formatter,
  required final VoidCallback? onNextMonth,
  required final VoidCallback? onPreviousMonth,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              container: true,
              child: Text(
                '${formatter.formatMonth(selectedMonth)} ${selectedMonth.year}',
                style: context.typography.titleMedium?.copyWith(
                  fontWeight: .w600,
                ),
              ),
            ),
          ),
          _buildMonthButton(
            context: context,
            label: 'Mês anterior',
            icon: Icons.chevron_left,
            onPress: onPreviousMonth,
          ),
          _buildMonthButton(
            context: context,
            label: 'Próximo mês',
            icon: Icons.chevron_right,
            onPress: onNextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback? onPress,
  }) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      container: true,
      label: label,
      child: IconButtonWidget(
        icon: icon,
        onPress: onPress,
        withoutBackground: true,
        backgroundColor: Colors.transparent,
        iconColor: context.colors.onSurfaceVariant,
      ),
    ),
  );
}
