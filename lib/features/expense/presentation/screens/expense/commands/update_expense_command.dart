import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class UpdateExpenseCommand({required IExpenseRepository repository})
    implements ICommand {
  final Command<
    ({String id, int? cents, String? description, DateTime? occurredOn}),
    UpdateRepositoryType?
  >
  execute =
      Command.createAsync<
        ({String id, int? cents, String? description, DateTime? occurredOn}),
        UpdateRepositoryType?
      >(
        initialValue: null,
        (parameters) => repository.update(
          id: parameters.id,
          cents: parameters.cents,
          description: parameters.description,
          occurredOn: parameters.occurredOn,
        ),
      );

  @override
  void dispose() => execute.dispose();
}
