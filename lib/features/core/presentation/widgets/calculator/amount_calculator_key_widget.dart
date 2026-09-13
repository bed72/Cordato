import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class AmountCalculatorKeyWidget extends StatelessWidget {
  final String label;
  final bool isAction;
  final VoidCallback onTap;

  const AmountCalculatorKeyWidget({
    super.key,
    required this.label,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: BounceWidget.withOnPress(
          onPress: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: context.radius.cornerRadius100,
              color: isAction
                  ? context.colors.primary.withValues(alpha: 0.2)
                  : context.colors.onSurface.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Text(
                label,
                style: context.typography.bodyLarge?.copyWith(
                  fontWeight: .w800,
                  color: isAction
                      ? context.colors.primary
                      : context.colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
