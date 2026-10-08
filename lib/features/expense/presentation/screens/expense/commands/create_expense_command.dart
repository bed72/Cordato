import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class CreateExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<
    ({int cents, String description, DateTime? occurredOn}),
    CreateRepositoryType?
  >
  execute =
      Command.createAsync<
        ({int cents, String description, DateTime? occurredOn}),
        CreateRepositoryType?
      >(
        initialValue: null,
        (parameters) => repository.create(
          cents: parameters.cents,
          occurredOn: parameters.occurredOn,
          description: parameters.description,
        ),
      );

  @override
  void dispose() => execute.dispose();
}
