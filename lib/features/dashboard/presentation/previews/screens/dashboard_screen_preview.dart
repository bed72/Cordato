import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/user_preview_repository.dart';

@CordatoPreview(
  group: 'Dashboard / Telas',
  name: 'Dashboard',
  size: cordatoPhonePreviewSize,
)
Widget previewDashboardScreen() => PreviewResourceWidget<GetUserNameCommand>(
  create: () => GetUserNameCommand(repository: const UserPreviewRepository()),
  dispose: (command) => command.dispose(),
  builder: (command) => DashboardScreen(
    command: command,
    onBudgetPressed: () {},
    onExpensePressed: () {},
    onMenuPressed: () {},
    onNotificationsPressed: () {},
  ),
);
