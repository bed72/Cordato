import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/headers/collapsible_header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/empty_state_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/mixins/expenses_screen_state_mixin.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_item_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_filters_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_skeleton_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_feedback_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_dismissible_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_group_header_widget.dart';

final class const ExpensesScreen({
  super.key,
  required final IDateFormatter dateFormatter,
  required final ExpensesBloc Function() bloc,
  required final IMoneyFormatter moneyFormatter,
  final String? category,
  final ({DateTime from, DateTime to})? period,
}) extends StatefulWidget {
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

final class _ExpensesScreenState extends State<ExpensesScreen>
    with ExpensesScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ExpensesBloc, ExpensesState>(
          bloc: bloc,
          builder: (_, _) => _buildContent(),
          listener: (_, state) => handleState(state),
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
        CollapsibleHeaderWidget(
          title: 'Despesas',
          description: 'Acompanhe todas as suas despesas.',
          leading: BackButtonWidget(onPress: goBack),
        ),
        if (activeCategory != null || activePeriod != null)
          SliverToBoxAdapter(
            child: ExpensesFiltersWidget(
              periodLabel: periodLabel,
              categoryLabel: categoryLabel,
              onRemoveCategory: canRemoveFilters ? removeCategoryFilter : null,
              onRemovePeriod: canRemoveFilters ? removePeriodFilter : null,
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
                  onConfirmDelete: () => confirmDeleteExpense(expense.id),
                  onEdit:
                      isLoading || pendingDeleteId != null || isEditingExpense
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
        if (bloc.state.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              icon: bloc.state.data.hasFilters
                  ? Icons.search_off_outlined
                  : Icons.receipt_long_outlined,
              title: bloc.state.data.hasFilters
                  ? 'Nenhuma despesa encontrada'
                  : 'Nenhuma despesa por aqui',
              description: bloc.state.data.hasFilters
                  ? 'Experimente ajustar os filtros.'
                  : 'Seus gastos aparecerão aqui.',
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _buildFeedback()),
          const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
        ],
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

    return const SizedBox.shrink();
  }
}
