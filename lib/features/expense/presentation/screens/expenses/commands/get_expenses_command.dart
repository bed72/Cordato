import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class GetExpensesCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<({int pageSize, String? pageLink}), GetRepositoryType?>
  execute =
      Command.createAsync<
        ({int pageSize, String? pageLink}),
        GetRepositoryType?
      >(
        initialValue: null,
        (pagination) => repository.get(
          pageSize: pagination.pageSize,
          pageLink: pagination.pageLink,
        ),
      );

  @override
  void dispose() => execute.dispose();
}
