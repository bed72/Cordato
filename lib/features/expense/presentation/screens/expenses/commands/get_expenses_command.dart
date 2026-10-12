import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class GetExpensesCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<
    ({int pageSize, String? pageLink, DateTime? from, DateTime? to}),
    GetRepositoryType?
  >
  execute =
      Command.createAsync<
        ({int pageSize, String? pageLink, DateTime? from, DateTime? to}),
        GetRepositoryType?
      >(
        initialValue: null,
        (pagination) => repository.get(
          to: pagination.to,
          from: pagination.from,
          pageLink: pagination.pageLink,
          pageSize: pagination.pageSize,
        ),
      );

  @override
  void dispose() => execute.dispose();
}
