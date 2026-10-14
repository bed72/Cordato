import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class UpdateExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<
    ({String id, int? cents, String? description, DateTime? occurredOn}),
    ExpenseEntity?
  >
  execute =
      Command.createAsync<
        ({String id, int? cents, String? description, DateTime? occurredOn}),
        ExpenseEntity?
      >(initialValue: null, (parameters) async {
        final data = await repository.update(
          id: parameters.id,
          cents: parameters.cents,
          occurredOn: parameters.occurredOn,
          description: parameters.description,
        );

        return switch (data) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        };
      });

  @override
  void dispose() => execute.dispose();
}
