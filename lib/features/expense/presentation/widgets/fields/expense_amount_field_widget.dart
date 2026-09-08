import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class ExpenseAmountFieldWidget extends StatelessWidget {
  const ExpenseAmountFieldWidget({super.key});

  @override
  Widget build(BuildContext context) => const TextFieldWidget(
    label: 'Valor',
    hint: 'Ex: R\$ 125,00',
    inputAction: TextInputAction.next,
    keyboardType: TextInputType.number,
  );
}
