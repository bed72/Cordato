import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const SettingsPremiumBadgeWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const .symmetric(horizontal: 8.0, vertical: 2.0),
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.primary),
      borderRadius: context.radius.cornerRadiusFull,
    ),
    child: Text(
      'PREMIUM',
      style: context.typography.labelSmall?.copyWith(
        color: context.colors.primary,
        fontWeight: .w600,
      ),
    ),
  );
}
