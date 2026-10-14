import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class GetExpensesCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<
    ({
      int pageSize,
      DateTime? to,
      DateTime? from,
      String? category,
      String? pageLink,
    }),
    ExpensePageEntity?
  >
  execute =
      Command.createAsync<
        ({
          int pageSize,
          DateTime? to,
          DateTime? from,
          String? category,
          String? pageLink,
        }),
        ExpensePageEntity?
      >(
        initialValue: null,
        (pagination) async => switch (await repository.get(
          to: pagination.to,
          from: pagination.from,
          category: pagination.category,
          pageLink: pagination.pageLink,
          pageSize: pagination.pageSize,
        )) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        },
      );

  @override
  void dispose() => execute.dispose();
}
