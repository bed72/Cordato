import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

final class GetInsightsCommand({required IInsightRepository repository})
    implements ICommand {
  final Command<({int? year, int? month}), List<InsightEntity>?> execute =
      Command.createAsync<({int? year, int? month}), List<InsightEntity>?>(
        (filters) async => switch (await repository.get(
          year: filters.year,
          month: filters.month,
        )) {
          Right(:final value) => value,
          Left(:final value) => throw CommandFailureException(errors: value),
        },
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
