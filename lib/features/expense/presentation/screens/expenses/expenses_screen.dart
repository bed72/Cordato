import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_item_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expense_dismissible_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/delete_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_skeleton_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_feedback_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/mixins/expenses_screen_state_mixin.dart';

final class const ExpensesScreen({
  super.key,
  required final VoidCallback onBackPressed,
  required final GetExpensesCommand command,
  required final DeleteExpenseCommand deleteCommand,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
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
        child:
            CommandBuilder<
              ({int pageSize, String? pageLink}),
              GetRepositoryType?
            >(
              command: widget.command.execute,
              onSuccess: (_, _) => _content(),
              onError: (_, _, _, _) => _content(),
              whileRunning: (_, _, _) => _content(),
            ),
      ),
    );
  }

  RefreshIndicator _content() => RefreshIndicator(
    onRefresh: refreshExpenses,
    child: CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: .fromLTRB(16.0, 16.0, 16.0, 24.0),
            child: HeaderWidget(
              title: 'Despesas',
              description: 'Acompanhe todas as suas despesas.',
            ),
          ),
        ),
        SliverList.builder(
          itemCount: expenses.length,
          itemBuilder: (_, index) {
            final expense = expenses[index];

            return ExpenseDismissibleWidget(
              key: ValueKey(expense.id),
              id: expense.id,
              enabled:
                  !isLoading &&
                  !isEditingExpense &&
                  (pendingDeleteId == null || pendingDeleteId == expense.id),
              isDeleting: deletingExpenseId == expense.id,
              onConfirmDelete: () => confirmDeleteExpense(expense.id),
              onDeleted: () => removeDeletedExpense(expense.id),
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
            );
          },
        ),
        SliverToBoxAdapter(child: _feedback()),
        const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
      ],
    ),
  );

  Widget _feedback() {
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
      return const ExpensesFeedbackWidget(
        title: 'Ainda sem despesas',
        description: 'Seus gastos cadastrados aparecerão aqui.',
      );
    }
    return const SizedBox.shrink();
  }
}
