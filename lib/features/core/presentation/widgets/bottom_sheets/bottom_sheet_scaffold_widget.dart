import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class BottomSheetScaffoldWidget extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  const BottomSheetScaffoldWidget({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = context.radius.cornerRadius300;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: radius.topLeft,
          topRight: radius.topRight,
        ),
      ),
      child: Padding(
        padding:
            contentPadding ?? const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48.0,
                height: 6.0,
                margin: const EdgeInsets.only(bottom: 20.0),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.28),
                  borderRadius: context.radius.cornerRadiusFull,
                ),
              ),
            ),
            if (title != null) ...[
              Text(
                title!,
                style: context.typography.titleLarge?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6.0),
            ],
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: context.typography.bodyLarge?.copyWith(
                  color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6.0),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
