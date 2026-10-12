import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

final class GetInsightsCommand({required IInsightRepository repository})
    implements ICommand {
  final Command<({int? year, int? month}), GetRepositoryType?> execute =
      Command.createAsync<({int? year, int? month}), GetRepositoryType?>(
        (filters) => repository.get(year: filters.year, month: filters.month),
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
