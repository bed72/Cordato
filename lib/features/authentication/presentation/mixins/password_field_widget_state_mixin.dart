import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/widgets/password_field_widget.dart';

mixin PasswordFieldWidgetStateMixin on State<PasswordFieldWidget> {
  late bool _obscure = widget.obscure;

  bool get isObscured => widget.onToggle == null ? _obscure : widget.obscure;

  @override
  void didUpdateWidget(PasswordFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscure != oldWidget.obscure) _obscure = widget.obscure;
  }

  void toggle() {
    if (widget.onToggle case final callback?) {
      callback();
    } else {
      setState(() => _obscure = !_obscure);
    }
  }
}
