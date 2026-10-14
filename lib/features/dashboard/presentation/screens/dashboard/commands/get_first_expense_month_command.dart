import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

final class GetFirstExpenseMonthCommand({
  required final IExpenseRepository repository,
}) implements ICommand {
  bool _disposed = false;

  late final Command<void, DateTime?> execute =
      Command.createAsyncNoParam<DateTime?>(
        _loadFirstMonth,
        initialValue: null,
      );

  Future<DateTime?> _loadFirstMonth() async {
    DateTime? firstMonth;
    String? pageLink;
    final visitedLinks = <String>{};

    do {
      final data = await repository.get(pageLink: pageLink);
      if (_disposed) return null;
      if (data.isLeft) throw CommandFailureException(errors: data.left);

      for (final expense in data.right.items) {
        final date = expense.occurredOn;
        final month = DateTime(date.year, date.month);
        if (firstMonth == null || month.isBefore(firstMonth)) {
          firstMonth = month;
        }
      }

      pageLink = data.right.next;
      if (pageLink != null && !visitedLinks.add(pageLink)) {
        throw CommandFailureException(errors: ErrorsEntity.unknown());
      }
    } while (pageLink != null);

    return firstMonth;
  }

  @override
  void dispose() {
    _disposed = true;
    execute.dispose();
  }
}
