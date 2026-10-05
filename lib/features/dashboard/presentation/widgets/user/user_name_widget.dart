import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/dashboard/presentation/mixins/user_name_widget_mixin.dart';
import 'package:cordato/features/dashboard/presentation/widgets/avatar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_skeleton_widget.dart';

final class const UserNameWidget({super.key})
    extends StatelessWidget
    with UserNameWidgetMixin {
  @override
  Widget build(BuildContext context) {
    return _content(context, 'Gabriel Ramos');
  }

  UserNameSkeletonWidget _skeleton(BuildContext context) =>
      UserNameSkeletonWidget(child: _content(context, 'Usuário'));

  Row _content(BuildContext context, String name) => Row(
    spacing: 12.0,
    children: [
      AvatarDashboardWidget(initial: initial(name)),
      Column(
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
