import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class CreateExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<ExpenseEntity, void> create =
      Command.createAsyncNoResult<ExpenseEntity>((expense) async {
        final response = await repository.create(expense);
        response.fold((failure) => throw failure, (_) {});
      });

  @override
  void dispose() => create.dispose();
}
