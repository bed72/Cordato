import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/information/presentation/screens/help/help_screen.dart';
import 'package:cordato/features/information/presentation/screens/privacy/privacy_screen.dart';
import 'package:cordato/features/information/presentation/screens/terms/terms_screen.dart';

@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Termos de uso / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Termos de uso / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewTermsScreen() => const TermsScreen();

@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Privacidade / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Privacidade / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewPrivacyScreen() => const PrivacyScreen();

@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Ajuda / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Ajuda / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewHelpScreen() => const HelpScreen();

@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Privacidade / Texto ampliado',
  size: cordatoPhonePreviewSize,
)
Widget previewPrivacyLargeTextScreen() => MediaQuery(
  data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
  child: const PrivacyScreen(),
);

@CordatoPreview(
  group: 'Informações / Telas',
  name: 'Ajuda / Tela estreita',
  size: Size(320.0, 568.0),
)
Widget previewHelpNarrowScreen() => const HelpScreen();
