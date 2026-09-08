import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class AmountCalculatorFieldWidget extends StatelessWidget {
  final String value;

  const AmountCalculatorFieldWidget({super.key, required this.value});

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
