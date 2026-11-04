import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/form_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

mixin FormSignUpWidgetStateMixin on State<FormSignUpWidget> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String email = '';
  String? emailFailure;

  String password = '';
  String? passwordFailure;

  List<ErrorEntity> showErrors(List<ErrorEntity> errors) {
    final remaining = <ErrorEntity>[];
    final emailMessages = <String>[];
    final passwordMessages = <String>[];

    for (final error in errors) {
      final message = AuthenticationErrorMessageFormatter.format(
        error,
        fallback: 'Confira os dados informados.',
      );
      if ((error.status == '400' && error.pointer == '/email') ||
          ((error.status == '422' || error.status == '409') &&
              error.pointer == '/data/attributes/email')) {
        emailMessages.add(message);
        continue;
      }
      if ((error.status == '400' &&
              (error.pointer == '/password' ||
                  error.pointer == '/passwordConfirm')) ||
          (error.status == '422' &&
              error.pointer == '/data/attributes/password')) {
        passwordMessages.add(message);
        continue;
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void clear() {
    emailController.clear();
    passwordController.clear();

    setState(() {
      email = '';
      password = '';
      emailFailure = null;
      passwordFailure = null;
    });
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
