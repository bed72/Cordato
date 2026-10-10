import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_chart_widget.dart';
import 'package:cordato/features/metrics/presentation/widgets/expense_metrics_skeleton_widget.dart';

final class const MetricsSectionWidget({
  super.key,
  required final DateTime selectedMonth,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  required final GetExpenseMetricsCommand command,
  required final VoidCallback? onRetry,
  required final VoidCallback? onNextMonth,
  required final VoidCallback? onPreviousMonth,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CommandBuilder(
    command: command.execute,
    whileRunning: (_, _, _) => _buildSection(
      context: context,
      child: const ExpenseMetricsSkeletonWidget(),
      loading: true,
    ),
    onError: (_, _, _, _) => _buildSection(
      context: context,
      child: _failure(context: context),
    ),
    onSuccess: (_, _) => switch (command.execute.value) {
      Right(:final value) => _buildSection(
        context: context,
        child: _metrics(context: context, metrics: value),
        period: value.startDate,
      ),
      Left() => _buildSection(
        context: context,
        child: _failure(context: context),
      ),
      null => _buildSection(
        context: context,
        child: const ExpenseMetricsSkeletonWidget(),
        loading: true,
      ),
    },
  );

  Widget _buildSection({
    required BuildContext context,
    required Widget child,
    bool loading = false,
    DateTime? period,
  }) => Padding(
    padding: const .fromLTRB(20.0, 0, 20.0, 24.0),
    child: Column(
      crossAxisAlignment: .start,
      spacing: 8.0,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '${dateFormatter.formatMonth(period ?? selectedMonth)} ${(period ?? selectedMonth).year}',
                  style: context.typography.titleMedium?.copyWith(
                    fontWeight: .w600,
                  ),
                ),
              ),
            ),
            _buildMonthButton(
              context: context,
              label: 'Mês anterior',
              icon: Icons.chevron_left,
              onPress: loading ? null : onPreviousMonth,
            ),
            _buildMonthButton(
              context: context,
              label: 'Próximo mês',
              icon: Icons.chevron_right,
              onPress: loading ? null : onNextMonth,
            ),
          ],
        ),
        child,
      ],
    ),
  );

  Widget _buildMonthButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback? onPress,
  }) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      label: label,
      child: IconButtonWidget(
        icon: icon,
        onPress: onPress,
        backgroundColor: Colors.transparent,
        iconColor: context.colors.onSurfaceVariant,
        withoutBackground: true,
      ),
    ),
  );

  Widget _metrics({
    required BuildContext context,
    required ExpenseMetricsEntity metrics,
  }) {
    final categories = metrics.categories;
    return Column(
      crossAxisAlignment: .start,
      spacing: 12.0,
      children: [
        Semantics(
          label:
              'Total de gastos: ${moneyFormatter.formatCents(metrics.totalAmount)}',
          excludeSemantics: true,
          child: Text(
            moneyFormatter.formatCents(metrics.totalAmount),
            style: context.typography.headlineMedium?.copyWith(
              fontWeight: .w600,
              letterSpacing: -1.0,
            ),
          ),
        ),
        if (metrics.totalAmount == 0)
          _message(
            context: context,
            message: 'Nenhuma despesa registrada neste período.',
          )
        else if (categories == null || categories.isEmpty)
          _message(
            context: context,
            message: 'A distribuição por categoria não está disponível.',
          )
        else
          ExpenseMetricsChartWidget(
            categories: categories,
            moneyFormatter: moneyFormatter,
          ),
      ],
    );
  }

  Widget _message({required BuildContext context, required String message}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          message,
          style: context.typography.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );

  Widget _failure({required BuildContext context}) => Column(
    spacing: 12.0,
    crossAxisAlignment: .start,
    children: [
      Text(
        'Não foi possível carregar os gastos por categoria.',
        style: context.typography.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      TextButtonWidget(label: 'Tentar novamente', onTap: onRetry),
    ],
  );
}
