import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/password_field_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/mixins/form_sign_up_widget_state_mixin.dart';

final class const FormSignUpWidget({
  super.key,
  final bool enabled = true,
  required final EmailValidation emailValidation,
  required final PasswordValidation passwordValidation,
  required final ValueChanged<({String email, String password})> onSubmit,
}) extends StatefulWidget {
  @override
  State<FormSignUpWidget> createState() => FormSignUpWidgetState();
}

class FormSignUpWidgetState extends State<FormSignUpWidget>
    with FormSignUpWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16.0,
      crossAxisAlignment: .stretch,
      children: [
        EmailFieldWidget(
          enabled: widget.enabled,
          label: 'E-mail',
          controller: emailController,
          failure: emailFailure,
          hint: 'Digite seu e-mail',
          onChanged: onEmailChanged,
          onEditingComplete: focusPassword,
        ),
        PasswordFieldWidget(
          focusNode: passwordFocus,
          enabled: widget.enabled,
          label: 'Senha',
          controller: passwordController,
          inputAction: .done,
          hint: 'Crie uma senha',
          failure: passwordFailure,
          onSubmitted: (_) => submit(),
          onChanged: onPasswordChanged,
        ),
      ],
    );
  }
}
