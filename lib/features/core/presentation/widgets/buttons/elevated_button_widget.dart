import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/animations/animation.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';

final class const ElevatedButtonWidget({
  super.key,
  required final VoidCallback? onTap,
  final Widget? child,
  final String? label,
  final bool? isLoading,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BounceWidget.withOnPress(
    onPress: onTap,
    child: ElevatedButton(
      onPressed: onTap,
      child: SwitcherAnimation(
        child: (isLoading ?? false)
            ? Builder(
                key: const ValueKey('loading'),
                builder: (context) => CircularProgressIndicatorWidget(
                  width: 20.0,
                  height: 20.0,
                  color: DefaultTextStyle.of(context).style.color,
                ),
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
