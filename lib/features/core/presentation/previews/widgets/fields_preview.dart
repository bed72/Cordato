import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/fields/date_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/amount_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/checkbox_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/password_field_widget.dart';

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
    label: 'Descrição',
    hint: 'Campo desabilitado',
    enabled: false,
  ),
);

@CordatoPreview(group: 'Core / Campos', name: 'Senha', size: Size(390.0, 220.0))
Widget previewPasswordFieldWidget() => _fieldShell(
  PasswordFieldWidget(
    label: 'Senha',
    hint: 'Digite sua senha',
    initialValue: 'cordato123',
    obscure: true,
    onToggle: () {},
  ),
);

@CordatoPreview(
  group: 'Core / Campos',
  name: 'Checkbox',
  size: Size(390.0, 200.0),
)
Widget previewCheckboxFieldWidget() => _fieldShell(
  CheckboxFieldWidget(
    checked: true,
    label: 'Aceito os termos de uso e a política de privacidade.',
    onChanged: (_) {},
  ),
);

@CordatoPreview(group: 'Core / Campos', name: 'Data', size: Size(390.0, 220.0))
Widget previewDateFieldWidget() => _fieldShell(
  DateFieldWidget(
    label: 'Período',
    hint: 'Selecione o período',
    value: DateTimeRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    ),
    onTap: () {},
  ),
);

@CordatoPreview(group: 'Core / Campos', name: 'Valor', size: Size(390.0, 220.0))
Widget previewAmountFieldWidget() => _fieldShell(
  AmountFieldWidget(value: 259990, formatter: MoneyFormatter(), onTap: () {}),
);
