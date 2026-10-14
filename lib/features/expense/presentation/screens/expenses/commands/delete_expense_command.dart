import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class DeleteExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<String, bool?> execute = Command.createAsync<String, bool?>((
    id,
  ) async {
    final result = await repository.delete(id: id);
    return switch (result) {
      Right(:final value) => value,
      Left(:final value) => throw CommandFailureException(errors: value),
    };
  }, initialValue: null);

  @override
  void dispose() => execute.dispose();
}
