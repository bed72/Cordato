import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/welcome/presentation/screens/welcome_screen.dart';

@CordatoPreview(
  group: 'Boas-vindas / Telas',
  name: 'Boas-vindas',
  size: cordatoPhonePreviewSize,
)
Widget previewWelcomeScreen() => WelcomeScreen(onContinueWithEmail: (_) {});

@CordatoPreview(
  group: 'Boas-vindas / Telas',
  name: 'Boas-vindas em tela dividida',
  size: Size(412.0, 400.0),
)
Widget previewWelcomeSplitScreen() =>
    WelcomeScreen(onContinueWithEmail: (_) {});
