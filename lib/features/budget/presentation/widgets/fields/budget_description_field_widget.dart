import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const BudgetDescriptionFieldWidget({
  super.key,
  required final TextEditingController controller,
  final String? failure,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFieldWidget(
    failure: failure,
    label: 'Descrição',
    inputAction: .done,
    onChanged: onChanged,
    controller: controller,
    onSubmitted: onSubmitted,
    textCapitalization: .sentences,
    hint: 'Ex: Orçamento de setembro',
  );
}
