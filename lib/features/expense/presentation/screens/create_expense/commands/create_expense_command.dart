import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/application/data/create_expense_input.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class CreateExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<CreateExpenseInput, CreateRepositoryType?> execute =
      Command.createAsync<CreateExpenseInput, CreateRepositoryType?>(
        initialValue: null,
        (input) => repository.create(input: input),
      );

  @override
  void dispose() => execute.dispose();
}
