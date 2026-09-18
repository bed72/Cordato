import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const FieldMagicLinkWidget({
  super.key,
  required final TextEditingController controller,
  required final ValueChanged<String> onSubmitted,
  final String? failure,
  final ValueChanged<String>? onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextFieldWidget(
      label: 'Email',
      failure: failure,
      inputAction: .done,
      onChanged: onChanged,
      controller: controller,
      onSubmitted: onSubmitted,
      hint: 'email@exemplo.com',
      keyboardType: .emailAddress,
      autofillHints: const [AutofillHints.email],
    );
  }
}
