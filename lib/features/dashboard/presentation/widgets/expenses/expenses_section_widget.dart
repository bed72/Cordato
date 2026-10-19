import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_item_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_empty_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_skeleton_widget.dart';

final class const ExpensesSectionWidget({
  super.key,
  required final int limit,
  required final ExpensePageEntity? page,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final value = page;
    return value == null
        ? _buildSection(context: context, child: _buildLoading())
        : value.items.isEmpty
        ? _buildSection(context: context, child: const ExpensesEmptyWidget())
        : _buildSection(
            context: context,
            hasItems: true,
            child: _buildItems(value.items),
          );
  }

  Column _buildSection({
    required BuildContext context,
    required Widget child,
    bool hasItems = false,
  }) => Column(
    spacing: 8.0,
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    children: [
      Padding(
        padding: const .symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Despesas recentes',
                  style: context.typography.titleMedium?.copyWith(
                    fontWeight: .w600,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ),
            if (hasItems)
              TextButtonWidget(
                label: 'Ver tudo',
                onTap: () => _openExpenses(context),
              ),
          ],
        ),
      ),
      child,
    ],
  );

  ExpensesSkeletonWidget _buildLoading() =>
      ExpensesSkeletonWidget(count: limit);

  Future<void> _openExpenses(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final bloc = context.read<DashboardBloc>();
    final month = bloc.state.selectedMonth;
    bool changed = false;
    await context.pushNamed(
      RouteEnum.expenses.path,
      arguments: (
        from: DateTime(month.year, month.month),
        to: DateTime(month.year, month.month + 1, 0),
        onExpensesChanged: () => changed = true,
      ),
    );
    if (changed &&
        context.mounted &&
        !bloc.isClosed &&
        identical(context.read<DashboardBloc>(), bloc)) {
      bloc.add(DashboardExpensesChanged());
    }
  }

  Column _buildItems(List<ExpenseEntity> expenses) => Column(
    mainAxisSize: .min,
    children: [
      for (final expense in expenses.take(limit))
        ExpenseItemWidget(
          key: ValueKey(expense.id),
          category: expense.category,
          description: expense.description,
          formattedDate: dateFormatter.formatLongDate(expense.occurredOn),
          formattedValue: moneyFormatter.formatCents(expense.cents.cents),
        ),
    ],
  );
}
