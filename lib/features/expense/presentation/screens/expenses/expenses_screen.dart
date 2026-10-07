import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';

import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_item_widget.dart';
import 'package:cordato/features/expense/presentation/commands/get_expenses_command.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_feedback_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/mixins/expenses_screen_state_mixin.dart';

final class const ExpensesScreen({
  super.key,
  required final VoidCallback onBackPressed,
  required final GetExpensesCommand command,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
}) extends StatefulWidget {
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

final class _ExpensesScreenState extends State<ExpensesScreen>
    with ExpensesScreenStateMixin {
  @override
  Widget build(BuildContext context) => Scaffold(
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

            return ExpenseItemWidget(
              category: expense.category,
              description: expense.description,
              formattedDate: widget.dateFormatter.formatLongDate(
                expense.occurredOn,
              ),
              formattedValue: widget.moneyFormatter.formatCents(
                expense.cents.cents,
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
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Semantics(
          label: 'Carregando despesas',
          child: CircularProgressIndicatorWidget(color: context.colors.primary),
        ),
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
