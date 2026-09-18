import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

class const PasswordFieldWidget({
  super.key,
  required final String hint,
  required final String label,
  required final bool obscure,
  required final VoidCallback onToggle,
  final String? failure,
  final ValueChanged<String>? onChanged,
  final TextInputAction? inputAction,
  final String? initialValue,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFieldWidget(
    hint: hint,
    label: label,
    failure: failure,
    onChanged: onChanged,
    obscureText: obscure,
    inputAction: inputAction,
    initialValue: initialValue,
    hideTrailingIconWhenEmpty: true,
    onTrailingIconTap: onToggle,
    trailingIcon: obscure
        ? Icons.visibility_outlined
        : Icons.visibility_off_outlined,
  );
}
