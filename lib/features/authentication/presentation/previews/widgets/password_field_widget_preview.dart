import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/authentication/presentation/widgets/password_field_widget.dart';

@CordatoPreview(
  group: 'Authentication / Campos',
  name: 'Senha com olho animado',
  size: Size(390.0, 220.0),
)
Widget previewAnimatedPasswordFieldWidget() => const Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: .all(24.0),
      child: PasswordFieldWidget(
        label: 'Senha',
        hint: 'Digite uma senha',
        initialValue: 'SenhaDePreview',
      ),
    ),
  ),
);
