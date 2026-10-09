import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

mixin InsightCardWidgetMixin on StatelessWidget {
  ({IconData icon, Color color}) appearance(
    BuildContext context,
    String type,
  ) => switch (type) {
    'registered_amount_increase' => (
      icon: Icons.trending_up,
      color: context.colors.primary,
    ),
    'category_lead_streak' => (
      icon: Icons.autorenew_outlined,
      color: context.isDark ? const Color(0xFF20D6CC) : Colors.teal.shade700,
    ),
    _ => (
      icon: Icons.lightbulb_outline,
      color: context.colors.onSurfaceVariant,
    ),
  };
}
