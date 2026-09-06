import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class AvatarDashboardWidget extends StatelessWidget {
  final String initial;

  const AvatarDashboardWidget({super.key, required this.initial});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: context.radius.cornerRadius100,
    ),
    child: SizedBox(
      width: 48.0,
      height: 48.0,
      child: Center(
        child: Text(
          initial,
          style: context.typography.headlineSmall?.copyWith(
            fontWeight: .w700,
            color: context.colors.onPrimaryContainer,
          ),
        ),
      ),
    ),
  );
}
