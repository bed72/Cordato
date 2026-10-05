import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/password_field_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/mixins/form_sign_in_widget_state_mixin.dart';

final class const FormSignInWidget({
  super.key,
  required final EmailValidation emailValidation,
  required final PasswordValidation passwordValidation,
  required final ValueChanged<({String email, String password})> onSubmit,
}) extends StatefulWidget {
  @override
  State<FormSignInWidget> createState() => FormSignInWidgetState();
}

class FormSignInWidgetState extends State<FormSignInWidget>
    with FormSignInWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16.0,
      crossAxisAlignment: .stretch,
      children: [
        EmailFieldWidget(
          label: 'E-mail',
          failure: emailFailure,
          hint: 'Digite seu e-mail',
          onChanged: onEmailChanged,
        ),
        PasswordFieldWidget(
          label: 'Senha',
          inputAction: .done,
          hint: 'Digite sua senha',
          failure: passwordFailure,
          onSubmitted: (_) => submit(),
          onChanged: onPasswordChanged,
        ),
      ],
    );
  }
}
