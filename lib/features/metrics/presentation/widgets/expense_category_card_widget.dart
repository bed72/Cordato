import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_category_metrics_extension.dart';

final class const ExpenseCategoryCardWidget({
  super.key,
  required final IMoneyFormatter formatter,
  required final ExpenseCategoryMetricsEntity category,
  final VoidCallback? onExpensesChanged,
  final ({DateTime from, DateTime to})? period,
  final bool compact = false,
  final bool highlighted = false,
  final bool illustrated = false,
}) extends StatelessWidget {
  double get illustrationSize => 160.0;

  double get illustrationHeight => compact ? 0.0 : 180.0;

  Future<void> _openExpenses(BuildContext context) async {
    final range = period;
    if (range == null || ModalRoute.of(context)?.isCurrent == false) return;
    await context.pushNamed(
      RouteEnum.expenses.path,
      arguments: (from: range.from, to: range.to, category: category.category),
    );
    if (context.mounted) onExpensesChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = period == null
        ? null
        : () => _openExpenses(context);
    final color = category.color(context);
    final amount = formatter.formatCents(category.totalAmount);
    final percentage = _buildPercentageLabel(percentage: category.percentage);

    final card = Semantics(
      onTap: onTap,
      container: true,
      button: onTap != null,
      excludeSemantics: true,
      label: '${category.label}, $amount, $percentage do total',
      hint: onTap == null ? null : 'Ver despesas de ${category.label}',
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
          child: Stack(
            fit: .expand,
            children: [
              if (highlighted || illustrated)
                Positioned(
                  right: -32.0,
                  bottom: -32.0,
                  width: illustrationSize,
                  height: illustrationSize,
                  child: Skeleton.ignore(
                    child: ImageWidget(
                      fit: .contain,
                      alt: category.asset.alt,
                      width: illustrationSize,
                      height: illustrationSize,
                      source: category.asset.source,
                      fallback: AssetEnum.categoryOthers.source,
                    ),
                  ),
                ),
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
                    Text(
                      category.label,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: context.typography.titleSmall,
                    ),
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
            ],
          ),
        ),
      ),
    );

    return onTap == null
        ? card
        : BounceWidget.withOnPress(onPress: onTap, child: card);
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
          24.0,
    );

    return 34.0 +
        headerHeight +
        12.0 +
        _buildTextHeight(
          context: context,
          width: contentWidth,
          text: category.label,
          style: context.typography.titleSmall,
          maxLines: 1,
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
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: width);

    final height = painter.height;
    painter.dispose();
    return height;
  }
}
