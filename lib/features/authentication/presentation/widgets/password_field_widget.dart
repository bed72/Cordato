import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/authentication/presentation/mixins/password_field_widget_state_mixin.dart';

class const PasswordFieldWidget({
  super.key,
  required final String hint,
  required final String label,
  final bool enabled = true,
  final bool obscure = true,
  final String? failure,
  final String? initialValue,
  final VoidCallback? onToggle,
  final TextInputAction? inputAction,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
  final TextEditingController? controller,
  final Iterable<String> autofillHints = const [AutofillHints.password],
}) extends StatefulWidget {
  @override
  State<PasswordFieldWidget> createState() => _PasswordFieldWidgetState();
}

class _PasswordFieldWidgetState extends State<PasswordFieldWidget>
    with PasswordFieldWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return TextFieldWidget(
      hint: widget.hint,
      label: widget.label,
      failure: widget.failure,
      enabled: widget.enabled,
      obscureText: isObscured,
      onTrailingIconTap: toggle,
      onChanged: widget.onChanged,
      controller: widget.controller,
      inputAction: widget.inputAction,
      hideTrailingIconWhenEmpty: true,
      onSubmitted: widget.onSubmitted,
      initialValue: widget.initialValue,
      autofillHints: widget.autofillHints,
      trailingIcon: isObscured ? lucide.eye : lucide.eye_off,
    );
  }
}
