import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class DeleteExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<String, DeleteRepositoryType?> execute =
      Command.createAsync<String, DeleteRepositoryType?>(
        (id) => repository.delete(id: id),
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
