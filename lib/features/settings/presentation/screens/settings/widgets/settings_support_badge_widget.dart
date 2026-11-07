import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const SettingsSupportBadgeWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        borderRadius: .circular(6.0),
        border: .all(color: context.colors.primary),
      ),
      child: Text(
        'NOS AJUDE',
        style: context.typography.labelSmall?.copyWith(
          fontWeight: .w600,
          color: context.colors.primary,
        ),
      ),
    );
  }
}
