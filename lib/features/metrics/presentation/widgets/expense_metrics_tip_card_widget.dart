import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class const ExpenseMetricsTipCardWidget({super.key})
    extends StatelessWidget {
  static const _title = 'Entenda seus gastos';
  static const _description =
      'Toque em uma categoria para ver as despesas do período.';

  bool _hasLargerText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14.0) > 14.0;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;
    final largerText = _hasLargerText(context);

    return Semantics(
      container: true,
      child: Container(
        padding: const .all(16.0),
        decoration: BoxDecoration(
          borderRadius: context.radius.cornerRadius300,
          border: .all(color: color.withValues(alpha: 0.20)),
          color: Color.alphaBlend(
            color.withValues(alpha: context.isDark ? 0.10 : 0.05),
            context.colors.surface,
          ),
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            ExcludeSemantics(
              child: BackgroundIconWidget(
                width: 40.0,
                height: 40.0,
                iconSize: 22.0,
                iconColor: color,
                icon: Icons.info_outline,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              _title,
              maxLines: largerText ? null : 1,
              overflow: largerText ? .clip : .ellipsis,
              style: context.typography.titleSmall,
            ),
            const SizedBox(height: 8.0),
            Text(
              _description,
              maxLines: largerText ? null : 3,
              overflow: largerText ? .clip : .ellipsis,
              style: context.typography.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  double buildHeightFor({
    required BuildContext context,
    required double width,
  }) {
    final largerText = _hasLargerText(context);
    final contentWidth = math.max(1.0, width - 34.0);

    return 34.0 +
        40.0 +
        12.0 +
        _textHeight(
          context: context,
          text: _title,
          width: contentWidth,
          style: context.typography.titleSmall,
          maxLines: largerText ? null : 1,
        ) +
        8.0 +
        _textHeight(
          context: context,
          text: _description,
          width: contentWidth,
          style: context.typography.bodySmall,
          maxLines: largerText ? null : 3,
        );
  }

  double _textHeight({
    required BuildContext context,
    required String text,
    required double width,
    required int? maxLines,
    required TextStyle? style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);

    final height = painter.height;
    painter.dispose();
    return height;
  }
}
