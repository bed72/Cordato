import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/screens/password_recovery/password_recovery_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_event.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';

mixin PasswordRecoveryScreenStateMixin on State<PasswordRecoveryScreen> {
  final emailController = TextEditingController();
  String? emailFailure;

  @override
  void initState() {
    super.initState();
    emailController.text = widget.bloc.state.sentEmail ?? '';
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void onEmailChanged(String _) {
    if (emailFailure != null) setState(() => emailFailure = null);
  }

  void submit() => _send(isResend: false);

  void resend() => _send(isResend: true);

  void _send({required bool isResend}) {
    if (!widget.bloc.state.canSubmit) return;
    switch (widget.validation(emailController.text)) {
      case Invalid(:final message):
        setState(() => emailFailure = message);
      case Valid(:final value):
        context.dismissKeyboard();
        widget.bloc.add(
          isResend
              ? PasswordRecoveryResendRequested(email: value)
              : PasswordRecoverySubmitted(email: value),
        );
    }
  }

  void handleRecovery(PasswordRecoveryState state) {
    if (!mounted || state is! PasswordRecoveryFailure) return;
    final fieldErrors = state.errors.errors
        .where(
          (error) =>
              error.status == '400' &&
              error.pointer == '/email' &&
              error.detail != null,
        )
        .toList();
    if (fieldErrors.isNotEmpty) {
      setState(
        () =>
            emailFailure = fieldErrors.map((error) => error.detail!).join('\n'),
      );
      if (fieldErrors.length == state.errors.errors.length) return;
    }
    context.showToast(
      variant: .error,
      title: 'Não foi possível enviar o e-mail',
      description: 'Verifique sua conexão e tente novamente.',
    );
  }
}
