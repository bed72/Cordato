import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/mixins/form_sign_in_widget_state_mixin.dart';

final class const FormSignInWidget({
  super.key,
  final bool enabled = true,
  required final EmailValidation validation,
  required final ValueChanged<String> onSubmit,
}) extends StatefulWidget {
  @override
  State<FormSignInWidget> createState() => FormSignInWidgetState();
}

final class FormSignInWidgetState extends State<FormSignInWidget>
    with FormSignInWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return EmailFieldWidget(
      label: 'E-mail',
      inputAction: .done,
      failure: emailFailure,
      enabled: widget.enabled,
      hint: 'Digite seu e-mail',
      onChanged: onEmailChanged,
      onSubmitted: (_) => submit(),
    );
  }
}
