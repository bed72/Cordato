import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/expense/presentation/screens/expense/commands/get_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/create_expense_command.dart';
import 'package:cordato/features/expense/presentation/screens/expense/commands/update_expense_command.dart';

import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_form_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/expense_skeleton_widget.dart';
import 'package:cordato/features/expense/presentation/screens/expense/mixins/expense_screen_state_mixin.dart';

import 'package:cordato/features/expense/presentation/screens/expense/validators/expense_form_validator.dart';

final class const ExpenseScreen({
  super.key,
  final String? id,
  final VoidCallback? onExpensesChanged,
  required final VoidCallback onBackPressed,
  required final IDateFormatter dateFormatter,
  required final GetExpenseCommand getCommand,
  required final IMoneyFormatter moneyFormatter,
  required final ExpenseFormValidator validator,
  required final CreateExpenseCommand createCommand,
  required final UpdateExpenseCommand updateCommand,
  required final ValueChanged<BuildContext> onExpenseCreated,
  required final void Function(BuildContext context, ExpenseEntity expense)
  onExpenseUpdated,
}) extends StatefulWidget {
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

final class _ExpenseScreenState extends State<ExpenseScreen>
    with ExpenseScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ExpenseAppBarWidget(onBackPressed: widget.onBackPressed),
      body: SafeArea(
        child: widget.id == null
            ? _buildForm()
            : CommandBuilder<String, GetByIdRepositoryType?>(
                command: widget.getCommand.execute,
                onSuccess: (_, _) => _buildContent(),
                onError: (_, _, _, _) => _buildContent(),
                whileRunning: (_, _, _) => _buildSkeleton(),
              ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) return _buildSkeleton();
    if (expense != null) return _buildForm(initialExpense: expense);

    return Center(
      child: SingleChildScrollView(
        padding: const .all(16.0),
        child: Column(
          spacing: 16.0,
          crossAxisAlignment: .stretch,
          children: [
            Text(
              'Não foi possível carregar a despesa.',
              textAlign: .center,
              style: context.typography.titleMedium,
            ),
            Text(loadErrorDescription, textAlign: .center),
            ElevatedButtonWidget(label: 'Tentar novamente', onTap: loadExpense),
          ],
        ),
      ),
    );
  }

  ExpenseSkeletonWidget _buildSkeleton() => ExpenseSkeletonWidget(
    child: _buildForm(
      enabled: false,
      initialExpense: ExpenseEntity(
        id: widget.id!,
        category: .other,
        occurredOn: .now(),
        cents: .create(cents: 1500).right,
        description: 'Descrição do gasto',
      ),
    ),
  );

  ExpenseFormWidget _buildForm({
    ExpenseEntity? initialExpense,
    bool enabled = true,
  }) => ExpenseFormWidget(
    key: ValueKey((widget.id, enabled)),
    id: widget.id,
    enabled: enabled,
    validator: widget.validator,
    initialExpense: initialExpense,
    createCommand: widget.createCommand,
    updateCommand: widget.updateCommand,
    dateFormatter: widget.dateFormatter,
    moneyFormatter: widget.moneyFormatter,
    onExpenseCreated: widget.onExpenseCreated,
    onExpenseUpdated: widget.onExpenseUpdated,
    onExpensesChanged: widget.onExpensesChanged,
  );
}
