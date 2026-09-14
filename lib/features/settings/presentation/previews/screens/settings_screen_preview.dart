import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/settings/presentation/screens/settings_screen.dart';

@CordatoPreview(
  group: 'Configurações / Telas',
  name: 'Configurações',
  size: cordatoPhonePreviewSize,
)
Widget previewSettingsScreen() => const SettingsScreen();
