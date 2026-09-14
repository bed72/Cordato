import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/dashboard/presentation/widgets/avatar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/menu_button_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_skeleton_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/notification_button_dashboard_widget.dart';

@CordatoPreview(
  group: 'Dashboard / Widgets',
  name: 'Cabeçalho',
  size: Size(390.0, 190.0),
)
Widget previewDashboardHeaderWidgets() => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: .center,
        spacing: 16.0,
        children: [
          MenuButtonDashboardWidget(onPress: () {}),
          const AvatarDashboardWidget(initial: 'G'),
          NotificationButtonDashboardWidget(onPress: () {}),
        ],
      ),
    ),
  ),
);

@CordatoPreview(
  group: 'Dashboard / Widgets',
  name: 'Nome carregando',
  size: Size(390.0, 150.0),
)
Widget previewUserNameSkeletonWidget() => const Scaffold(
  body: SafeArea(
    child: Padding(
      padding: EdgeInsets.all(24.0),
      child: UserNameSkeletonWidget(child: Text('Olá, Gabriel')),
    ),
  ),
);
