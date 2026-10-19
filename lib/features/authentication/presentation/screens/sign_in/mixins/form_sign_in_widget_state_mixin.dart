import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';

mixin FormSignInWidgetStateMixin on State<FormSignInWidget> {
  String email = '';
  String? emailFailure;

  String password = '';
  String? passwordFailure;

  List<ErrorEntity> showErrors(List<ErrorEntity> errors) {
    final emailMessages = <String>[];
    final remaining = <ErrorEntity>[];
    final passwordMessages = <String>[];

    for (final error in errors) {
      if (error.status == '422' && error.detail != null) {
        switch (error.pointer) {
          case '/data/attributes/email':
            emailMessages.add(error.detail!);
            continue;
          case '/data/attributes/password':
            passwordMessages.add(error.detail!);
            continue;
        }
      }
      remaining.add(error);
    }

    setState(() {
      emailFailure = emailMessages.isEmpty ? null : emailMessages.join('\n');
      passwordFailure = passwordMessages.isEmpty
          ? null
          : passwordMessages.join('\n');
    });
    return remaining;
  }

  void submit() {
    if (!widget.enabled) return;

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
