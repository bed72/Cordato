import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/validators/password_confirmation_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/reset_password_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';
import 'package:cordato/features/authentication/presentation/formatters/reset_password_error_message_formatter.dart';

mixin ResetPasswordScreenStateMixin on State<ResetPasswordScreen> {
  String? passwordFailure;
  String? confirmationFailure;

  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  final confirmationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    open();
  }

  @override
  void didUpdateWidget(covariant ResetPasswordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc != widget.bloc || oldWidget.token != widget.token) {
      passwordController.clear();
      confirmationController.clear();
      passwordFailure = null;
      confirmationFailure = null;
      open();
    }
  }

  @override
  void dispose() {
    confirmationFocus.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  void focusConfirmation() {
    if (widget.bloc.state.canSubmit) {
      confirmationFocus.requestFocus();
    }
  }

  void open() => widget.bloc.add(
    ResetPasswordOpened(hasToken: widget.token?.isNotEmpty == true),
  );

  void goToSignIn() {
    context
      ..dismissKeyboard()
      ..navigate(RouteEnum.welcome.path)
      ..pushNamed(RouteEnum.authenticationSignIn.path);
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

  void submit() {
    if (!widget.bloc.state.canSubmit) {
      return;
    }

    final password = widget.validation(passwordController.text);
    final confirmation = const PasswordConfirmationValidation()(
      password: passwordController.text,
      confirmation: confirmationController.text,
    );

    setState(() {
      passwordFailure = switch (password) {
        Invalid(:final message) => message,
        Valid() => null,
      };
      confirmationFailure = switch (confirmation) {
        Invalid(:final message) => message,
        Valid() => null,
      };
    });

    if ((password, confirmation) case (
      Valid(value: final newPassword),
      Valid(value: final confirmedPassword),
    )) {
      context.dismissKeyboard();

      widget.bloc.add(
        ResetPasswordSubmitted(
          token: widget.token ?? '',
          password: newPassword,
          passwordConfirm: confirmedPassword,
        ),
      );
    }
  }

  void handleReset(ResetPasswordState state) {
    if (!mounted) {
      return;
    }

    switch (state) {
      case ResetPasswordSuccess():
        _completeReset();
      case ResetPasswordInvalid():
        _showInvalidLink();
      case ResetPasswordFailure():
        _showResetFailure(state);
      default:
        break;
    }
  }

  void _completeReset() {
    context
      ..dismissKeyboard()
      ..showToast(
        variant: .success,
        title: 'Senha redefinida com sucesso',
        description: 'Entre com sua nova senha.',
      );

    goToSignIn();
  }

  void _showInvalidLink() {
    context
      ..dismissKeyboard()
      ..showToast(
        variant: .error,
        title: 'Link inválido ou expirado',
        description: 'Solicite um novo link de recuperação.',
      );

    goToSignIn();
  }

  void _showResetFailure(ResetPasswordFailure failure) {
    final fields = ResetPasswordErrorMessageFormatter.fields(failure.errors);

    setState(() {
      passwordFailure = fields.password;
      confirmationFailure = fields.confirmation;
    });

    if (fields.toast case final message?) {
      context.showToast(
        variant: .error,
        title: 'Não foi possível redefinir a senha',
        description: message,
      );
    }
  }
}
