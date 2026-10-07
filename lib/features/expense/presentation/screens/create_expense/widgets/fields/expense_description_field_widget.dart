import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const ExpenseDescriptionFieldWidget({
  super.key,
  required final TextEditingController controller,
  final String? failure,
  final bool enabled = true,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextFieldWidget(
      failure: failure,
      enabled: enabled,
      label: 'Descrição',
      hint: 'Ex: Mercado',
      inputAction: .next,
      onChanged: onChanged,
      controller: controller,
      onSubmitted: onSubmitted,
      textCapitalization: .sentences,
    );
  }
}
