import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/validators/password_confirmation_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/reset_password_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';

mixin ResetPasswordScreenStateMixin on State<ResetPasswordScreen> {
  String? passwordFailure;
  String? confirmationFailure;

  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();

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
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
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
    if (passwordFailure != null) setState(() => passwordFailure = null);
  }

  void onConfirmationChanged(String _) {
    if (confirmationFailure != null) setState(() => confirmationFailure = null);
  }

  void submit() {
    if (!widget.bloc.state.canSubmit) return;
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
    if (password case Valid(:final value)) {
      if (confirmation case Valid(value: final confirmed)) {
        context.dismissKeyboard();
        widget.bloc.add(
          ResetPasswordSubmitted(
            token: widget.token ?? '',
            password: value,
            passwordConfirm: confirmed,
          ),
        );
      }
    }
  }

  void handleReset(ResetPasswordState state) {
    if (!mounted) return;
    if (state is ResetPasswordSuccess || state is ResetPasswordInvalid) {
      context.dismissKeyboard();
      context.showToast(
        variant: state is ResetPasswordSuccess ? .success : .error,
        title: state is ResetPasswordSuccess
            ? 'Senha redefinida com sucesso'
            : 'Link inválido ou expirado',
        description: state is ResetPasswordSuccess
            ? 'Entre com sua nova senha.'
            : 'Solicite um novo link de recuperação.',
      );
      goToSignIn();
      return;
    }
    if (state is! ResetPasswordFailure) return;
    final passwordErrors = <String>[];
    final confirmationErrors = <String>[];
    var hasRemaining = state.errors.errors.isEmpty;
    for (final error in state.errors.errors) {
      if (error.status == '400' && error.detail != null) {
        if (error.pointer == '/password') {
          passwordErrors.add(error.detail!);
          continue;
        }
        if (error.pointer == '/passwordConfirm') {
          confirmationErrors.add(error.detail!);
          continue;
        }
      }
      hasRemaining = true;
    }
    setState(() {
      passwordFailure = passwordErrors.isEmpty
          ? null
          : passwordErrors.join('\n');
      confirmationFailure = confirmationErrors.isEmpty
          ? null
          : confirmationErrors.join('\n');
    });
    if (hasRemaining) {
      context.showToast(
        variant: .error,
        title: 'Não foi possível redefinir a senha',
        description: 'Verifique sua conexão e tente novamente.',
      );
    }
  }
}
