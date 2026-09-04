import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/presentation/widgets/avatar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_skeleton_widget.dart';

final class UserNameWidget extends StatelessWidget {
  final GetUserNameCommand command;

  const UserNameWidget({super.key, required this.command});

  String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    if (hour >= 18) return 'Boa noite';
    return 'Isso são horas?';
  }

  @override
  Widget build(BuildContext context) => CommandBuilder<void, String?>(
    command: command.execute,
    onNullData: (_, _) => _skeleton(context),
    whileRunning: (_, _, _) => _skeleton(context),
    onError: (context, _, _, _) => _content(context, 'Usuário'),
    onData: (context, name, _) => _content(context, name ?? 'Usuário'),
  );

  Widget _skeleton(BuildContext context) =>
      UserNameSkeletonWidget(child: _content(context, 'Usuário'));

  Widget _content(BuildContext context, String name) => Row(
    spacing: 12.0,
    children: [
      AvatarDashboardWidget(initial: _initial(name)),
      Column(
        mainAxisAlignment: .center,
        crossAxisAlignment: .start,
        children: [
          Text(
            _greeting(),
            style: context.typography.bodyMedium?.copyWith(
              fontWeight: .w600,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          Text(
            name,
            style: context.typography.titleMedium?.copyWith(
              fontWeight: .w700,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    ],
  );
}
