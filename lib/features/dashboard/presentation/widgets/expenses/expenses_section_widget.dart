import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_item_widget.dart';
import 'package:cordato/features/expense/presentation/commands/get_expenses_command.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_empty_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_failure_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_skeleton_widget.dart';

final class const ExpensesSectionWidget({
  super.key,
  required final int limit,
  required final GetExpensesCommand command,
  required final IDateFormatter dateFormatter,
  required final IMoneyFormatter moneyFormatter,
  final VoidCallback? onSeeAllExpensesPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CommandBuilder<
      ({int pageSize, String? pageLink}),
      GetRepositoryType?
    >(
      command: command.execute,
      onError: (_, _, _, _) => _section(context, _failure()),
      whileRunning: (_, _, _) => _section(context, _loading()),
      onSuccess: (_, _) => switch (command.execute.value) {
        Right(:final value) when value.items.isEmpty => _section(
          context,
          const ExpensesEmptyWidget(),
        ),
        Right(:final value) => _section(
          context,
          _items(value.items),
          hasItems: true,
        ),
        Left() => _section(context, _failure()),
        null => _section(context, _loading()),
      },
    );
  }

  Column _section(
    BuildContext context,
    Widget child, {
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
            if (hasItems && onSeeAllExpensesPressed != null)
              TextButtonWidget(
                label: 'Ver tudo',
                onTap: onSeeAllExpensesPressed,
              ),
          ],
        ),
      ),
      child,
    ],
  );

  ExpensesFailureWidget _failure() => const ExpensesFailureWidget();
  ExpensesSkeletonWidget _loading() => ExpensesSkeletonWidget(count: limit);

  Column _items(List<ExpenseEntity> expenses) => Column(
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
