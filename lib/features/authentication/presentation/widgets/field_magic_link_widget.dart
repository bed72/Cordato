import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class FieldMagicLinkWidget extends StatelessWidget {
  final String? failure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onSubmitted;
  final TextEditingController controller;

  const FieldMagicLinkWidget({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.failure,
    this.onChanged,
  });

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
