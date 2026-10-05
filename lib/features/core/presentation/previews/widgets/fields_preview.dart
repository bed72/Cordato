import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

Widget _fieldShell(Widget child) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: child,
    ),
  ),
);

@CordatoPreview(group: 'Core / Campos', name: 'Texto', size: Size(390.0, 220.0))
Widget previewTextFieldWidget() => _fieldShell(
  const TextFieldWidget(
    label: 'Descrição',
    hint: 'Ex: Mercado da semana',
    initialValue: 'Mercado',
  ),
);

@CordatoPreview(
  group: 'Core / Campos',
  name: 'Texto com erro',
  size: Size(390.0, 240.0),
)
Widget previewFailureTextFieldWidget() => _fieldShell(
  const TextFieldWidget(
    label: 'E-mail',
    hint: 'voce@exemplo.com',
    initialValue: 'email-inválido',
    failure: 'E-mail inválido',
  ),
);

@CordatoPreview(
  group: 'Core / Campos',
  name: 'Texto desabilitado',
  size: Size(390.0, 220.0),
)
Widget previewDisabledTextFieldWidget() => _fieldShell(
  const TextFieldWidget(
    enabled: false,
    label: 'Descrição',
    hint: 'Campo desabilitado',
  ),
);
