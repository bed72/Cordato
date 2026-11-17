import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

mixin FormSignInWidgetStateMixin on State<FormSignInWidget> {
  String email = '';
  String? emailFailure;

  List<ErrorEntity> showErrors(List<ErrorEntity> errors) {
    final fieldErrors = errors.where(
      AuthenticationErrorMessageFormatter.isEmailError,
    );
    setState(() {
      emailFailure = fieldErrors.isEmpty
          ? null
          : fieldErrors
                .map(AuthenticationErrorMessageFormatter.requestCode)
                .toSet()
                .join('\n');
    });
    return errors
        .where(
          (error) => !AuthenticationErrorMessageFormatter.isEmailError(error),
        )
        .toList();
  }

  void submit() {
    if (!widget.enabled) return;

    final validatedEmail = widget.validation(email);
    setState(() {
      emailFailure = switch (validatedEmail) {
        Invalid(:final message) => message,
        Valid() => null,
      };
    });

    if (validatedEmail case Valid(:final value)) widget.onSubmit(value);
  }

  void onEmailChanged(String value) {
    email = value;
    if (emailFailure != null) setState(() => emailFailure = null);
  }
}
