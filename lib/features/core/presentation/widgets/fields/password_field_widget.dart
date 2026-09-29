import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';

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
}) extends StatefulWidget {
  @override
  State<PasswordFieldWidget> createState() => _PasswordFieldWidgetState();
}

class _PasswordFieldWidgetState extends State<PasswordFieldWidget> {
  late bool _obscure = widget.obscure;

  bool get _isObscured => widget.onToggle == null ? _obscure : widget.obscure;

  @override
  void didUpdateWidget(PasswordFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscure != oldWidget.obscure) _obscure = widget.obscure;
  }

  void _toggle() {
    if (widget.onToggle case final callback?) {
      callback();
    } else {
      setState(() => _obscure = !_obscure);
    }
  }

  @override
  Widget build(BuildContext context) => TextFieldWidget(
    hint: widget.hint,
    label: widget.label,
    failure: widget.failure,
    enabled: widget.enabled,
    obscureText: _isObscured,
    onTrailingIconTap: _toggle,
    onChanged: widget.onChanged,
    controller: widget.controller,
    inputAction: widget.inputAction,
    hideTrailingIconWhenEmpty: true,
    onSubmitted: widget.onSubmitted,
    initialValue: widget.initialValue,
    autofillHints: const [AutofillHints.password],
    trailingIcon: _isObscured
        ? Icons.visibility_outlined
        : Icons.visibility_off_outlined,
  );
}
