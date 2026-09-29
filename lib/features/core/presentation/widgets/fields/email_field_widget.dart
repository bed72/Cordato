import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

final class const EmailFieldWidget({
  super.key,
  final String? failure,
  final String? initialValue,
  final String label = 'Email',
  final String hint = 'email@exemplo.com',
  final ValueChanged<String>? onChanged,
  final TextEditingController? controller,
  final ValueChanged<String>? onSubmitted,
  final TextInputAction inputAction = .next,
  final bool enabled = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFieldWidget(
    label: label,
    hint: hint,
    failure: failure,
    enabled: enabled,
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    inputAction: inputAction,
    initialValue: initialValue,
    keyboardType: .emailAddress,
    autofillHints: const [AutofillHints.email],
  );
}
