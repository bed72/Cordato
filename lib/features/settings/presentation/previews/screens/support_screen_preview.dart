import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/settings/presentation/screens/support/support_screen.dart';

@CordatoPreview(
  group: 'Settings / Telas',
  name: 'Apoio / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Settings / Telas',
  name: 'Apoio / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewSupportScreen() => const SupportScreen();
