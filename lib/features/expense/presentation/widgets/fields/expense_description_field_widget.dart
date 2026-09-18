import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const ExpenseDescriptionFieldWidget({
  super.key,
  required final TextEditingController controller,
  final String? failure,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
}) extends StatelessWidget {
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
