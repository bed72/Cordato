import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class BudgetDateFieldWidget extends StatelessWidget {
  const BudgetDateFieldWidget({super.key});

  @override
  Widget build(BuildContext context) => const TextFieldWidget(
    label: 'Período',
    readOnly: true,
    absorbing: true,
    hint: 'Data de início e término',
  );
}
