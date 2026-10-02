import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const ResendEmailVerificationCooldownLabelWidget({
  super.key,
  required final Duration remaining,
}) extends StatelessWidget {
  String? get _label {
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    if (seconds == 0) return null;

    final unit = seconds == 1 ? 'segundo' : 'segundos';
    return 'Você poderá reenviar em $seconds $unit';
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          alignment: .topCenter,
          sizeFactor: animation,
          child: child,
        ),
      ),
      child: label == null
          ? const SizedBox.shrink(key: ValueKey('resend-label-empty'))
          : Padding(
              key: const ValueKey('resend-label'),
              padding: const .only(bottom: 8.0),
              child: Align(
                alignment: .centerLeft,
                child: Text(
                  label,
                  style: context.typography.bodyMedium?.copyWith(
                    height: 1.0,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}
