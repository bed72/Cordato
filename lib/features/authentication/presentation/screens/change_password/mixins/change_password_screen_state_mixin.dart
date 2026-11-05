import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/session_redirect_scope_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/change_password_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_confirmation_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/change_password_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';
import 'package:cordato/features/authentication/presentation/formatters/change_password_error_message_formatter.dart';

mixin ChangePasswordScreenStateMixin on State<ChangePasswordScreen> {
  final currentFocus = FocusNode();
  final passwordFocus = FocusNode();
  final confirmationFocus = FocusNode();
  final currentController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();

  String? currentFailure;
  String? passwordFailure;
  String? confirmationFailure;
  void Function()? _releaseRedirect;

  @override
  void didUpdateWidget(covariant ChangePasswordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) {
      return;
    }

    _clearInputs();
    _release();
  }

  @override
  void dispose() {
    currentController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    currentFocus.dispose();
    passwordFocus.dispose();
    confirmationFocus.dispose();
    _release();
    super.dispose();
  }

  void _clearInputs() {
    currentController.clear();
    passwordController.clear();
    confirmationController.clear();
    currentFailure = null;
    passwordFailure = null;
    confirmationFailure = null;
  }

  void _release() {
    final release = _releaseRedirect;
    _releaseRedirect = null;
    release?.call();
  }

  void onCurrentChanged(String _) {
    if (currentFailure == null) {
      return;
    }

    setState(() => currentFailure = null);
  }

  void onPasswordChanged(String _) {
    if (passwordFailure == null) {
      return;
    }

    setState(() => passwordFailure = null);
  }

  void onConfirmationChanged(String _) {
    if (confirmationFailure == null) {
      return;
    }

    setState(() => confirmationFailure = null);
  }

  void goBack() => context.pop();

  void focusNewPassword() {
    if (widget.bloc.state.canSubmit) {
      passwordFocus.requestFocus();
    }
  }

  void focusConfirmation() {
    if (widget.bloc.state.canSubmit) {
      confirmationFocus.requestFocus();
    }
  }

  void submit() {
    if (!widget.bloc.state.canSubmit) {
      return;
    }

    final validation = _validateInputs();
    _showValidationFailures(validation);

    if (validation case (
      current: Valid(value: final currentPassword),
      password: Valid(value: final newPassword),
      confirmation: Valid(value: final confirmedPassword),
    )) {
      context.dismissKeyboard();
      _holdRedirect();

      widget.bloc.add(
        ChangePasswordSubmitted(
          oldPassword: currentPassword,
          password: newPassword,
          passwordConfirm: confirmedPassword,
        ),
      );
    }
  }

  ({
    ValidationResult<String> current,
    ValidationResult<String> password,
    ValidationResult<String> confirmation,
  })
  _validateInputs() {
    final validation = ChangePasswordValidation(
      passwordValidation: widget.validation,
    );

    return (
      current: validation.current(currentController.text),
      password: validation(
        oldPassword: currentController.text,
        password: passwordController.text,
      ),
      confirmation: const PasswordConfirmationValidation()(
        password: passwordController.text,
        confirmation: confirmationController.text,
      ),
    );
  }

  void _showValidationFailures(
    ({
      ValidationResult<String> current,
      ValidationResult<String> password,
      ValidationResult<String> confirmation,
    })
    validation,
  ) {
    setState(() {
      currentFailure = switch (validation.current) {
        Invalid(:final message) => message,
        Valid() => null,
      };
      passwordFailure = switch (validation.password) {
        Invalid(:final message) => message,
        Valid() => null,
      };
      confirmationFailure = switch (validation.confirmation) {
        Invalid(:final message) => message,
        Valid() => null,
      };
    });
  }

  void _holdRedirect() {
    _releaseRedirect ??= SessionRedirectScopeWidget.maybeOf(context)
        ?.hold(RouteEnum.authenticationChangePassword.path);
  }

  void retrySignOut() => widget.bloc.add(const ChangePasswordSignOutRetried());

  void handleChange(ChangePasswordState state) {
    if (!mounted) {
      return;
    }

    if (state.passwordChanged) {
      _clearInputs();
    }

    switch (state) {
      case ChangePasswordSuccess():
        _completeChange();
      case ChangePasswordFailure():
        _showChangeFailure(state);
      default:
        break;
    }
  }

  void _completeChange() {
    context
      ..dismissKeyboard()
      ..showToast(
        variant: .success,
        title: 'Senha alterada',
        description: 'Entre novamente.',
      )
      ..navigate(RouteEnum.authenticationSignIn.path);

    _release();
  }

  void _showChangeFailure(ChangePasswordFailure failure) {
    _release();

    final fields = ChangePasswordErrorMessageFormatter.fields(failure.errors);

    setState(() {
      currentFailure = fields.current;
      passwordFailure = fields.password;
      confirmationFailure = fields.confirmation;
    });

    if (fields.toast case final message?) {
      context.showToast(
        variant: .error,
        title: 'Não foi possível alterar a senha',
        description: message,
      );
    }
  }
}
