import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class GetExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<String, GetByIdRepositoryType?> execute =
      Command.createAsync<String, GetByIdRepositoryType?>(
        initialValue: null,
        (id) => repository.getById(id: id),
      );

  @override
  void dispose() => execute.dispose();
}
