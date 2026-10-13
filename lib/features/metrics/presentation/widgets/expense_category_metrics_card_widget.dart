import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_category_metrics_extension.dart';

final class const ExpenseCategoryMetricsCardWidget({
  super.key,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseCategoryMetricsEntity category,
  final bool highlighted = false,
  final bool illustrated = false,
  final bool compact = false,
}) extends StatelessWidget {
  double get illustrationSize => category.category == 'housing' ? 240.0 : 220.0;

  double get illustrationHeight => compact ? 60.0 : 180.0;

  @override
  Widget build(BuildContext context) {
    final color = category.color(context);
    final amount = moneyFormatter.formatCents(category.totalAmount);
    final percentage = _buildPercentageLabel(percentage: category.percentage);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${category.label}, $amount, $percentage do total',
      child: Container(
        clipBehavior: .antiAlias,
        decoration: BoxDecoration(
          borderRadius: context.radius.cornerRadius300,
          border: .all(color: color.withValues(alpha: 0.20)),
          color: Color.alphaBlend(
            color.withValues(alpha: context.isDark ? 0.10 : 0.05),
            context.colors.surface,
          ),
        ),
        child: ClipRRect(
          borderRadius: context.radius.cornerRadius300 - .circular(1.0),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const .all(16.0),
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      crossAxisAlignment: .start,
                      children: [
                        BackgroundIconWidget(
                          width: 40.0,
                          height: 40.0,
                          iconSize: 22.0,
                          iconColor: color,
                          icon: category.icon,
                          backgroundColor: color.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: const .symmetric(
                                vertical: 4.0,
                                horizontal: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: .all(.circular(8.0)),
                              ),
                              child: Text(
                                percentage,
                                style: context.typography.labelSmall?.copyWith(
                                  color: context.colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(category.label, style: context.typography.titleSmall),
                    const SizedBox(height: 8.0),
                    Text(
                      amount,
                      style: buildAmountStyle(
                        context: context,
                        highlighted: highlighted,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '$percentage do total',
                      style: context.typography.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (highlighted || illustrated) ...[
                const Spacer(),
                Align(
                  alignment: .bottomRight,
                  child: SizedBox(
                    width: illustrationSize,
                    height: illustrationHeight,
                    child: OverflowBox(
                      minWidth: illustrationSize,
                      maxWidth: illustrationSize,
                      minHeight: illustrationSize,
                      maxHeight: illustrationSize,
                      alignment: .bottomRight,
                      child: Transform.translate(
                        offset: Offset(46.0, compact ? 64.0 : 48.0),
                        child: Skeleton.ignore(
                          child: ImageWidget(
                            fit: .contain,
                            source: category.asset,
                            width: illustrationSize,
                            height: illustrationSize,
                            fallback: 'assets/images/categories/others.webp',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? buildAmountStyle({
    required BuildContext context,
    required bool highlighted,
  }) => context.typography.titleLarge?.copyWith(
    fontWeight: .w600,
    color: context.colors.onSurface,
    fontSize: highlighted ? 24.0 : 18.0,
  );

  double buildHeightFor({
    required BuildContext context,
    required double width,
    required bool highlighted,
    required IMoneyFormatter formatter,
    required ExpenseCategoryMetricsEntity category,
    bool illustrated = false,
  }) {
    final contentWidth = width - 34.0;
    final percentage = _buildPercentageLabel(percentage: category.percentage);
    final headerHeight = math.max(
      40.0,
      _buildTextHeight(
            context: context,
            text: percentage,
            style: context.typography.labelSmall,
            width: math.max(1.0, contentWidth - 64.0),
          ) +
          8.0,
    );

    return 34.0 +
        headerHeight +
        12.0 +
        _buildTextHeight(
          context: context,
          width: contentWidth,
          text: category.label,
          style: context.typography.titleSmall,
        ) +
        8.0 +
        _buildTextHeight(
          context: context,
          text: formatter.formatCents(category.totalAmount),
          style: buildAmountStyle(context: context, highlighted: highlighted),
          width: contentWidth,
        ) +
        8.0 +
        _buildTextHeight(
          context: context,
          text: '$percentage do total',
          style: context.typography.bodySmall,
          width: contentWidth,
        ) +
        (highlighted || illustrated ? illustrationHeight : 0.0);
  }

  String _buildPercentageLabel({required double percentage}) =>
      '${NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 1).format(percentage)}%';

  double _buildTextHeight({
    required BuildContext context,
    required String text,
    required double width,
    required TextStyle? style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);

    final height = painter.height;
    painter.dispose();
    return height;
  }
}
