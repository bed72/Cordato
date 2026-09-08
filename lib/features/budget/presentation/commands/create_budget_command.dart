import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';

import 'package:cordato/features/budget/domain/entities/budget_entity.dart';
import 'package:cordato/features/budget/domain/repositories/interface_budget_repository.dart';

final class CreateBudgetCommand implements ICommand {
  final Command<BudgetEntity, void> create;

  CreateBudgetCommand({required IBudgetRepository repository})
    : create = Command.createAsyncNoResult<BudgetEntity>((budget) async {
        final response = await repository.create(budget);
        response.fold((failure) => throw failure, (_) {});
      });

  @override
  void dispose() => create.dispose();
}
