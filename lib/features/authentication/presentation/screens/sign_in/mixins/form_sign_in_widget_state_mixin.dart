import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';

mixin FormSignInWidgetStateMixin on State<FormSignInWidget> {
  String email = '';
  String? emailFailure;

  String password = '';
  String? passwordFailure;

  void submit() {
    final validatedEmail = widget.emailValidation(email);
    final validatedPassword = widget.passwordValidation(password);
    setState(() {
      emailFailure = switch (validatedEmail) {
        Invalid(:final message) => message,
        Valid() => null,
      };
      passwordFailure = switch (validatedPassword) {
        Invalid(:final message) => message,
        Valid() => null,
      };
    });

    if (validatedEmail case Valid(value: final validEmail)) {
      if (validatedPassword case Valid(value: final validPassword)) {
        widget.onSubmit((email: validEmail, password: validPassword));
      }
    }
  }

  void onEmailChanged(String value) {
    email = value;
    if (emailFailure != null) setState(() => emailFailure = null);
  }

  void onPasswordChanged(String value) {
    password = value;
    if (passwordFailure != null) setState(() => passwordFailure = null);
  }
}
