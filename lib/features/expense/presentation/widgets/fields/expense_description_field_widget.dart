import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class ExpenseDescriptionFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final String? failure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const ExpenseDescriptionFieldWidget({
    super.key,
    required this.controller,
    this.failure,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextFieldWidget(
    label: 'Descrição',
    hint: 'Ex: Mercado',
    failure: failure,
    inputAction: TextInputAction.next,
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    textCapitalization: TextCapitalization.sentences,
  );
}
