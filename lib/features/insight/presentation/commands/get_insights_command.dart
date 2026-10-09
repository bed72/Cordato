import 'package:command_it/command_it.dart';

import 'package:cordato/features/core/presentation/commands/interface_command.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';

final class GetInsightsCommand({required IInsightRepository repository})
    implements ICommand {
  final Command<void, GetRepositoryType?> execute =
      Command.createAsyncNoParam<GetRepositoryType?>(
        repository.get,
        initialValue: null,
      );

  @override
  void dispose() => execute.dispose();
}
