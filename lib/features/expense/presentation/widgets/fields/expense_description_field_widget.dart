import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class ExpenseDescriptionFieldWidget extends StatelessWidget {
  const ExpenseDescriptionFieldWidget({super.key});

  @override
  Widget build(BuildContext context) => const TextFieldWidget(
    label: 'Descrição',
    hint: 'Ex: Mercado',
    inputAction: TextInputAction.next,
    textCapitalization: TextCapitalization.sentences,
  );
}
