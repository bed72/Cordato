import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const EmptyStateWidget({
  super.key,
  required final String title,
  required final IconData icon,
  final String? description,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const .all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320.0),
          child: MergeSemantics(
            child: Column(
              mainAxisSize: .min,
              children: [
                ExcludeSemantics(
                  child: IconWidget(
                    icon: icon,
                    size: 88.0,
                    color: context.colors.onSurface.withValues(alpha: .24),
                  ),
                ),
                const SizedBox(height: 24.0),
                Text(
                  title,
                  textAlign: .center,
                  style: context.typography.titleMedium?.copyWith(
                    fontWeight: .w600,
                    color: context.colors.onSurfaceVariant.withValues(
                      alpha: .85,
                    ),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    description!,
                    textAlign: .center,
                    style: context.typography.bodyMedium?.copyWith(
                      fontStyle: .italic,
                      color: context.colors.onSurfaceVariant.withValues(
                        alpha: .75,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
