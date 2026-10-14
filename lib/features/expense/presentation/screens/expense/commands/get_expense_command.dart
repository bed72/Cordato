import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class GetExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<String, ExpenseEntity?> execute =
      Command.createAsync<String, ExpenseEntity?>(
        initialValue: null,
        (id) async => switch (await repository.getById(id: id)) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        },
      );

  @override
  void dispose() => execute.dispose();
}
