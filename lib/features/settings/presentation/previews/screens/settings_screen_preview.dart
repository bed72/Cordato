import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/settings/presentation/commands/logout_command.dart';
import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';

@CordatoPreview(
  group: 'Configurações / Telas',
  name: 'Configurações',
  size: cordatoPhonePreviewSize,
)
Widget previewSettingsScreen() => PreviewResourceWidget<LogoutCommand>(
  create: () => LogoutCommand(repository: const LogoutPreviewRepository()),
  dispose: (command) => command.dispose(),
  builder: (command) => SettingsScreen(
    command: command,
    onBackPressed: (_) {},
    onHelpPressed: () {},
    onTermsPressed: () {},
    onPrivacyPressed: () {},
    onPersonalDataPressed: () {},
    onSubscriptionPressed: () {},
    onInvitePartnerPressed: () {},
  ),
);

@CordatoPreview(
  group: 'Configurações / Telas',
  name: 'Configurações compacta',
  size: Size(280.0, 520.0),
)
Widget previewCompactSettingsScreen() => PreviewResourceWidget<LogoutCommand>(
  create: () => LogoutCommand(repository: const LogoutPreviewRepository()),
  dispose: (command) => command.dispose(),
  builder: (command) => SettingsScreen(command: command, onBackPressed: (_) {}),
);
