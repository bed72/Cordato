import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/animations/animation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';

final class const DangerButtonWidget({
  super.key,
  required final VoidCallback? onTap,
  final Widget? child,
  final String? label,
  final bool? isLoading,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BounceWidget.withOnPress(
      onPress: (isLoading ?? false) ? null : onTap,
      child: ElevatedButton(
        onPressed: (isLoading ?? false) ? null : onTap,
        style: ElevatedButton.styleFrom(
          iconColor: context.colors.onError,
          overlayColor: Colors.transparent,
          foregroundColor: context.colors.onError,
          backgroundColor: context.colors.error.withValues(alpha: 0.9),
          disabledBackgroundColor: (isLoading ?? false)
              ? context.colors.error.withValues(alpha: 0.9)
              : Color.lerp(context.colors.error, context.colors.surface, .25),
          disabledForegroundColor: context.colors.onError,
          disabledIconColor: context.colors.onError,
        ),
        child: SwitcherAnimation(
          child: (isLoading ?? false)
              ? CircularProgressIndicatorWidget(
                  key: const ValueKey('loading'),
                  width: 20.0,
                  height: 20.0,
                  color: context.colors.onError,
                )
              : Row(
                  key: const ValueKey('content'),
                  mainAxisSize: .min,
                  spacing: (child != null && label != null) ? 8.0 : 0.0,
                  children: [?child, Text(label ?? '')],
                ),
        ),
      ),
    );
  }
}
