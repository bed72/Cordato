import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';

import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';

import 'package:cordato/features/dashboard/presentation/mixins/user_name_widget_mixin.dart';
import 'package:cordato/features/dashboard/presentation/widgets/avatar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_skeleton_widget.dart';

final class const UserNameWidget({
  super.key,
  required final UserCommand command,
  final VoidCallback? onAvatarPressed,
}) extends StatelessWidget with UserNameWidgetMixin {
  @override
  Widget build(BuildContext context) {
    return CommandBuilder<void, GetByIdRepositoryType?>(
      command: command.execute,
      whileRunning: (_, _, _) => _skeleton(context),
      onError: (_, _, _, _) => _content(context, '', failed: true),
      onSuccess: (_, _) => switch (command.execute.value) {
        Right(:final value) => _content(
          context,
          value.name,
          seed: value.avatar ?? 'cordato-user-${value.id}',
        ),
        Left() => _content(context, '', failed: true),
        null => _skeleton(context),
      },
    );
  }

  UserNameSkeletonWidget _skeleton(BuildContext context) =>
      UserNameSkeletonWidget(child: _content(context, 'Trocado'));

  Row _content(
    BuildContext context,
    String name, {
    bool failed = false,
    String seed = 'cordato-placeholder',
  }) => Row(
    spacing: 12.0,
    children: [
      AvatarDashboardWidget(seed: seed, onPress: onAvatarPressed),
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
            if (failed)
              LinkButtonWidget(
                label: 'Tentar novamente',
                onTap: command.execute.run,
              )
            else
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
