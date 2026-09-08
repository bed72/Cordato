import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class BudgetDescriptionFieldWidget extends StatelessWidget {
  const BudgetDescriptionFieldWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextFieldWidget(
      label: 'Descrição',
      textCapitalization: .sentences,
      hint: 'Ex: Orçamento de setembro',
    );
  }
}
