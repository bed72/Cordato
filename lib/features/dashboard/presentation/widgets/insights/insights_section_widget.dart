import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/presentation/widgets/insights_list_widget.dart';
import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';
import 'package:cordato/features/insight/presentation/widgets/insights_skeleton_widget.dart';

final class const InsightsSectionWidget({
  super.key,
  required final GetInsightsCommand command,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CommandBuilder<({int? year, int? month}), List<InsightEntity>?>(
      command: command.execute,
      whileRunning: (_, _, _) =>
          _buildSection(context, const InsightsSkeletonWidget()),
      onError: (_, _, _, _) => const SizedBox.shrink(),
      onNullData: (_, _) =>
          _buildSection(context, const InsightsSkeletonWidget()),
      onData: (_, insights, _) => insights!.isEmpty
          ? const SizedBox.shrink()
          : _buildSection(context, InsightsListWidget(insights: insights)),
    );
  }

  Padding _buildSection(BuildContext context, Widget child) => Padding(
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
}
