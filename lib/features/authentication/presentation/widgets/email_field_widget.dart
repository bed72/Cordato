import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const EmailFieldWidget({
  super.key,
  final String? failure,
  final bool enabled = true,
  final String? initialValue,
  final String label = 'Email',
  final ValueChanged<String>? onChanged,
  final String hint = 'email@exemplo.com',
  final TextEditingController? controller,
  final VoidCallback? onEditingComplete,
  final ValueChanged<String>? onSubmitted,
  final TextInputAction inputAction = .next,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextFieldWidget(
      label: label,
      hint: hint,
      failure: failure,
      enabled: enabled,
      onChanged: onChanged,
      controller: controller,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      inputAction: inputAction,
      initialValue: initialValue,
      keyboardType: .emailAddress,
      autofillHints: const [AutofillHints.email],
    );
  }
}
