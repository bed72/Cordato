import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

class PasswordFieldWidget extends StatelessWidget {
  final String hint;
  final String label;
  final bool obscure;
  final String? failure;
  final String? initialValue;
  final VoidCallback onToggle;
  final TextInputAction? inputAction;
  final ValueChanged<String>? onChanged;

  const PasswordFieldWidget({
    super.key,
    required this.hint,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.failure,
    this.onChanged,
    this.inputAction,
    this.initialValue,
  });

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
