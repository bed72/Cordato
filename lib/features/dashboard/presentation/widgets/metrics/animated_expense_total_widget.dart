import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final class const AnimatedExpenseTotalWidget({
  super.key,
  required final int? cents,
  required final IMoneyFormatter formatter,
  final bool isLoading = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Widget value;
    final totalCents = cents;

    final animationsDisabled =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final style = context.typography.headlineMedium?.copyWith(
      fontWeight: .w600,
      letterSpacing: -1.0,
    );

    if (isLoading || animationsDisabled || totalCents == null) {
      value = Text(
        totalCents == null ? '—' : formatter.formatCents(totalCents),
        style: style,
      );
    } else {
      value = TweenAnimationBuilder<int>(
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 700),
        tween: IntTween(begin: 0, end: totalCents),
        builder: (_, animatedCents, _) =>
            Text(formatter.formatCents(animatedCents), style: style),
      );
    }

    return Semantics(
      excludeSemantics: true,
      label: isLoading || totalCents == null
          ? 'Carregando total de gastos'
          : 'Total de gastos: ${formatter.formatCents(totalCents)}',
      child: value,
    );
  }
}
