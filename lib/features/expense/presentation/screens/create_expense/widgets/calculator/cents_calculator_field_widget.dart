import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const CentsCalculatorFieldWidget({
  super.key,
  required final String value,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFieldWidget(
    key: ValueKey(value),
    label: 'Valor',
    readOnly: true,
    absorbing: true,
    hint: 'Ex: R\$ 1.000,00',
    initialValue: value.isEmpty ? null : value,
  );
}
