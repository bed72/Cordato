import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/presentation/extensions/user_presentation_extension.dart';

import 'package:cordato/features/dashboard/presentation/mixins/user_name_widget_mixin.dart';
import 'package:cordato/features/dashboard/presentation/widgets/avatar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_skeleton_widget.dart';

final class const UserNameWidget({
  super.key,
  required final UserEntity? user,
  final bool isLoading = false,
}) extends StatelessWidget with UserNameWidgetMixin {
  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildSkeleton(context);

    return _buildContent(
      context,
      user?.displayName ?? 'Cordato',
      seed: user == null
          ? 'cordato-placeholder'
          : user?.avatar ?? 'cordato-user-${user?.id}',
    );
  }

  UserNameSkeletonWidget _buildSkeleton(BuildContext context) =>
      UserNameSkeletonWidget(child: _buildContent(context, 'Cordato'));

  Row _buildContent(
    BuildContext context,
    String name, {
    String seed = 'cordato-placeholder',
  }) => Row(
    spacing: 12.0,
    children: [
      AvatarDashboardWidget(seed: seed),
      Expanded(
        child: Column(
          mainAxisAlignment: .center,
          crossAxisAlignment: .start,
          children: [
            Text(
              greeting(),
              style: context.typography.bodyMedium?.copyWith(
                fontWeight: .w600,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            Text(
              name,
              maxLines: 1,
              overflow: .ellipsis,
              style: context.typography.titleMedium?.copyWith(
                fontWeight: .w700,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
