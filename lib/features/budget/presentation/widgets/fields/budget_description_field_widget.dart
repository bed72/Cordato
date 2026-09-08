import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class BudgetDescriptionFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final String? failure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const BudgetDescriptionFieldWidget({
    super.key,
    required this.controller,
    this.failure,
    this.onChanged,
    this.onSubmitted,
  });

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
