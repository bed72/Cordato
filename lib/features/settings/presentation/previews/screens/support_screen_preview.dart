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
@CordatoPreview(
  group: 'Settings / Telas',
  name: 'Apoio / Tela compacta',
  size: Size(320.0, 568.0),
)
@CordatoPreview(
  group: 'Settings / Telas',
  name: 'Apoio / Paisagem compacta',
  size: Size(568.0, 320.0),
)
Widget previewSupportScreen() => const SupportScreen();

@CordatoPreview(
  group: 'Settings / Telas',
  name: 'Apoio / Texto ampliado',
  size: cordatoPhonePreviewSize,
)
@CordatoPreview(
  group: 'Settings / Telas',
  name: 'Apoio / Compacta com texto ampliado',
  size: Size(320.0, 568.0),
)
Widget previewSupportScreenLargeText() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: const SupportScreen(),
  ),
);
