import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class const AnimatedExpenseTotalWidget({
  super.key,
  required final int cents,
  required final IMoneyFormatter formatter,
  final int? initialCents,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final style = context.typography.headlineMedium?.copyWith(
      fontWeight: .w600,
      letterSpacing: -1.0,
    );

    return Semantics(
      excludeSemantics: true,
      label: 'Total de gastos: ${formatter.formatCents(cents)}',
      child: animationsDisabled
          ? Text(formatter.formatCents(cents), style: style)
          : TweenAnimationBuilder<double>(
              curve: Curves.easeOutCubic,
              duration: const Duration(milliseconds: 300),
              tween: Tween(begin: initialCents == null ? 0.0 : 1.0, end: 1.0),
              builder: (_, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: TweenAnimationBuilder<int>(
                curve: Curves.easeOutCubic,
                duration: const Duration(milliseconds: 500),
                tween: IntTween(end: cents, begin: initialCents ?? cents),
                builder: (_, cents, _) =>
                    Text(formatter.formatCents(cents), style: style),
              ),
            ),
    );
  }
}
