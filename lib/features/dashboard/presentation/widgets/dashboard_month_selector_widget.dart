import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';

final class const DashboardMonthSelectorWidget({
  super.key,
  required final DateTime selectedMonth,
  required final IDateFormatter formatter,
  required final VoidCallback? onNextMonth,
  required final VoidCallback? onPreviousMonth,
  final bool isLoading = false,
  final bool showNavigation = true,
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
          if (isLoading)
            Semantics(
              label: 'Carregando Dashboard',
              child: ExcludeSemantics(
                child: Skeletonizer(
                  child: Row(
                    spacing: 8.0,
                    children: [
                      for (int index = 0; index < 2; index++)
                        SizedBox(
                          width: 48.0,
                          height: 48.0,
                          child: Bone.square(
                            size: 48.0,
                            borderRadius: context.radius.cornerRadius100,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else if (showNavigation) ...[
            _buildMonthButton(
              context: context,
              label: 'Mês anterior',
              icon: lucide.chevron_left,
              onPress: onPreviousMonth,
            ),
            const SizedBox(width: 8.0),
            _buildMonthButton(
              context: context,
              label: 'Próximo mês',
              icon: lucide.chevron_right,
              onPress: onNextMonth,
            ),
          ],
        ],
      ),
    );
  }

  Tooltip _buildMonthButton({
    required BuildContext context,
    required String label,
    required lucide.LucideAnimatedIconData icon,
    required VoidCallback? onPress,
  }) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      container: true,
      label: label,
      enabled: onPress != null,
      child: IconButtonWidget(
        icon: icon,
        iconSize: 26.0,
        onPress: onPress,
        withoutBackground: false,
        borderRadius: context.radius.cornerRadius100,
        backgroundColor: context.colors.onSurface.withValues(alpha: .04),
        iconColor: onPress == null
            ? context.colors.onSurface.withValues(alpha: .38)
            : context.colors.onSurface,
      ),
    ),
  );
}
