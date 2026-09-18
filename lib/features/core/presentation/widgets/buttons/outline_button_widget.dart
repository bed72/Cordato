import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/animations/animation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';

final class const OutlineButtonWidget({
  super.key,
  required final VoidCallback? onTap,
  final Widget? child,
  final String? label,
  final bool? isLoading,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BounceWidget.withOnPress(
    onPress: onTap,
    child: OutlinedButton(
      onPressed: onTap,
      child: SwitcherAnimation(
        child: (isLoading ?? false)
            ? CircularProgressIndicatorWidget(
                key: ValueKey('loading'),
                width: 20.0,
                height: 20.0,
                color: context.colors.primary,
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
