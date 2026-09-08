import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class ExpenseDateFieldWidget extends StatelessWidget {
  const ExpenseDateFieldWidget({super.key});

  @override
  Widget build(BuildContext context) => const TextFieldWidget(
    label: 'Data',
    hint: 'DD/MM/AAAA',
    inputAction: TextInputAction.done,
    keyboardType: TextInputType.datetime,
  );
}
