import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const CentsCalculatorKeyWidget({
  super.key,
  required final String label,
  required final VoidCallback onTap,
  final bool isAction = false,
}) extends StatelessWidget {
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
