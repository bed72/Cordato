import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/animations/animation.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';

final class TextButtonWidget extends StatelessWidget {
  final String? label;
  final Widget? child;
  final bool? isLoading;
  final VoidCallback? onTap;

  const TextButtonWidget({
    super.key,
    required this.onTap,
    this.child,
    this.label,
    this.isLoading,
  });

  @override
  Widget build(BuildContext context) => BounceWidget.withOnPress(
    onPress: onTap,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: .zero,
        minimumSize: .zero,
        alignment: .centerLeft,
        tapTargetSize: .shrinkWrap,
        overlayColor: Colors.transparent,
        backgroundColor: Colors.transparent,
      ),
      child: SwitcherAnimation(
        child: (isLoading ?? false)
            ? const CircularProgressIndicatorWidget(
                key: ValueKey('loading'),
                width: 20.0,
                height: 20.0,
                color: Colors.transparent,
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
