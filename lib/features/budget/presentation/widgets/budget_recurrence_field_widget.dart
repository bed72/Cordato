import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';

final class const BudgetRecurrenceFieldWidget({
  super.key,
  required final bool value,
  required final ValueChanged<bool> onChanged,
}) extends StatelessWidget {
  static const _animationDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: true,
      container: true,
      label: 'Repetir automaticamente',
      hint: 'Continuar usando esse valor nos próximos períodos.',
      child: ExcludeSemantics(
        child: Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: Column(
                spacing: 4.0,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Repetir automaticamente',
                    style: context.typography.bodyLarge?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: .w500,
                    ),
                  ),
                  Text(
                    'Continuar usando esse valor nos próximos períodos.',
                    style: context.typography.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            BounceWidget.withOnPress(
              onPress: () => onChanged(!value),
              child: AnimatedContainer(
                width: 52.0,
                height: 32.0,
                padding: const .all(4.0),
                duration: _animationDuration,
                curve: Easing.standardDecelerate,
                alignment: value ? .centerRight : .centerLeft,
                decoration: BoxDecoration(
                  borderRadius: context.radius.cornerRadius050,
                  color: value
                      ? context.colors.primary
                      : context.colors.surface,
                  border: .all(
                    color: value
                        ? context.colors.primary
                        : context.colors.outline,
                  ),
                ),
                child: AnimatedContainer(
                  width: 24.0,
                  height: 24.0,
                  duration: _animationDuration,
                  curve: Easing.standardDecelerate,
                  decoration: BoxDecoration(
                    shape: .rectangle,
                    borderRadius: .all(Radius.circular(8.0)),
                    color: value
                        ? context.colors.onPrimary
                        : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
