import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/dashboard/presentation/widgets/insights/insights_failure_widget.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';
import 'package:cordato/features/insight/presentation/widgets/insights_list_widget.dart';
import 'package:cordato/features/insight/presentation/widgets/insights_skeleton_widget.dart';

final class const InsightsSectionWidget({
  super.key,
  required final GetInsightsCommand command,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CommandBuilder<void, GetRepositoryType?>(
        command: command.execute,
        whileRunning: (_, _, _) =>
            _section(context, const InsightsSkeletonWidget()),
        onError: (_, _, _, _) => _section(context, _failure()),
        onSuccess: (_, _) => switch (command.execute.value) {
          Right(:final value) when value.isEmpty => const SizedBox.shrink(),
          Right(:final value) => _section(
            context,
            InsightsListWidget(insights: value),
          ),
          Left() => _section(context, _failure()),
          null => _section(context, const InsightsSkeletonWidget()),
        },
      );

  Widget _section(BuildContext context, Widget child) => Padding(
    padding: const .only(bottom: 24.0),
    child: Column(
      spacing: 12.0,
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 20.0),
          child: Semantics(
            header: true,
            child: Text(
              'Insights',
              style: context.typography.titleMedium?.copyWith(
                fontWeight: .w600,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );

  Widget _failure() => InsightsFailureWidget(onRetry: command.execute.run);
}
