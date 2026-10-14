import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/mixins/expenses_screen_state_mixin.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_item_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_filters_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_skeleton_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_feedback_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_dismissible_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_group_header_widget.dart';

final class const ExpensesScreen({
  super.key,
  required final VoidCallback onBackPressed,
  required final IDateFormatter dateFormatter,
  required final GetExpensesCommand getCommand,
  required final IMoneyFormatter moneyFormatter,
  required final DeleteExpenseCommand deleteCommand,
  final String? category,
  final VoidCallback? onExpensesChanged,
  final ({DateTime from, DateTime to})? period,
  final Future<ExpenseEntity?> Function(String id)? onExpensePressed,
}) extends StatefulWidget {
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

final class _ExpensesScreenState extends State<ExpensesScreen>
    with ExpensesScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ExpensesAppBarWidget(onBackPressed: widget.onBackPressed),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.getCommand.execute.isRunning,
          builder: (_, _) =>
              CommandBuilder<
                ({
                  int pageSize,
                  DateTime? to,
                  DateTime? from,
                  String? category,
                  String? pageLink,
                }),
                ExpensePageEntity?
              >(
                command: widget.getCommand.execute,
                onData: (_, _, _) => _buildContent(),
                onNullData: (_, _) => _buildContent(),
                onError: (_, _, _, _) => _buildContent(),
                whileRunning: (_, _, _) => _buildContent(),
              ),
        ),
      ),
    );
  }

  RefreshIndicator _buildContent() => RefreshIndicator(
    onRefresh: refreshExpenses,
    child: CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const .fromLTRB(16.0, 24.0, 16.0, 0.0),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const HeaderWidget(
                  title: 'Despesas',
                  description: 'Acompanhe todas as suas despesas.',
                ),
                if (activeCategory != null || activePeriod != null) ...[
                  const SizedBox(height: 12.0),
                  ExpensesFiltersWidget(
                    periodLabel: periodLabel,
                    categoryLabel: categoryLabel,
                    onRemoveCategory: canRemoveFilters
                        ? removeCategoryFilter
                        : null,
                    onRemovePeriod: canRemoveFilters
                        ? removePeriodFilter
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: expenses.length,
          itemBuilder: (_, index) {
            final expense = expenses[index];
            final group = widget.dateFormatter.relativeGroupHeader(
              expense.occurredOn,
            );
            final startsGroup =
                index == 0 ||
                widget.dateFormatter.relativeGroupHeader(
                      expenses[index - 1].occurredOn,
                    ) !=
                    group;

            return Column(
              key: ValueKey(expense.id),
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                if (startsGroup)
                  ExpensesGroupHeaderWidget(
                    label: group,
                    topSpacing: index == 0 ? 8.0 : 16.0,
                  ),
                ExpenseDismissibleWidget(
                  key: ValueKey(expense.id),
                  id: expense.id,
                  enabled:
                      !isLoading &&
                      !isEditingExpense &&
                      (pendingDeleteId == null ||
                          pendingDeleteId == expense.id),
                  isDeleting: deletingExpenseId == expense.id,
                  onDeleted: () => removeDeletedExpense(expense.id),
                  onConfirmDelete: () => confirmDeleteExpense(expense.id),
                  onEdit:
                      widget.onExpensePressed == null ||
                          isLoading ||
                          pendingDeleteId != null ||
                          isEditingExpense
                      ? null
                      : () => editExpense(expense.id),
                  onAccessibleDelete: isLoading || pendingDeleteId != null
                      ? null
                      : () => deleteExpenseAccessibly(expense.id),
                  child: ExpenseItemWidget(
                    category: expense.category,
                    description: expense.description,
                    formattedDate: widget.dateFormatter.formatLongDate(
                      expense.occurredOn,
                    ),
                    formattedValue: widget.moneyFormatter.formatCents(
                      expense.cents.cents,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        SliverToBoxAdapter(child: _buildFeedback()),
        const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
      ],
    ),
  );

  Widget _buildFeedback() {
    if (isLoading) {
      return Semantics(
        label: 'Carregando despesas',
        child: ExpensesSkeletonWidget(count: expenses.isEmpty ? 8 : 3),
      );
    }

    if (hasFailure) {
      return ExpensesFeedbackWidget(
        title: 'Não foi possível carregar as despesas.',
        description: 'Tente novamente para continuar.',
        onRetry: retry,
      );
    }

    if (hasLoaded && expenses.isEmpty) {
      return ExpensesFeedbackWidget(
        title: 'Ainda sem despesas',
        description: activeCategory != null
            ? 'Não há despesas para $filterLabel.'
            : periodLabel == null
            ? 'Seus gastos cadastrados aparecerão aqui.'
            : 'Não há despesas em $periodLabel.',
      );
    }

    return const SizedBox.shrink();
  }
}
