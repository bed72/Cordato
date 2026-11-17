import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/code/code_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_event.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_state.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

mixin CodeScreenStateMixin on State<CodeScreen> {
  final controller = TextEditingController();
  late String _userId;
  String? codeFailure;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId;
    widget.resendBloc.add(const ResendEmailStartedEvent());
  }

  @override
  void didUpdateWidget(covariant CodeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.email != widget.email) {
      _userId = widget.userId;
      controller.clear();
      codeFailure = null;
    }

    if (oldWidget.resendBloc != widget.resendBloc) {
      widget.resendBloc.add(const ResendEmailStartedEvent());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void confirm() {
    if (!widget.codeBloc.state.canSubmit ||
        widget.resendBloc.state.isSubmitting) {
      return;
    }

    context.dismissKeyboard();
    final validatedCode = widget.validation(controller.text);

    switch (validatedCode) {
      case Invalid(:final message):
        setState(() => codeFailure = message);
      case Valid(:final value):
        setState(() => codeFailure = null);
        widget.codeBloc.add(CodeSubmittedEvent(userId: _userId, code: value));
    }
  }

  void resend() {
    if (!widget.codeBloc.state.canSubmit ||
        !widget.resendBloc.state.canSubmit) {
      return;
    }

    context.dismissKeyboard();
    widget.resendBloc.add(ResendEmailSubmittedEvent(email: widget.email));
  }

  void changeEmail() {
    if (!widget.codeBloc.state.canSubmit ||
        widget.resendBloc.state.isSubmitting) {
      return;
    }

    context.dismissKeyboard();
    context.replace(RouteEnum.authenticationSignIn.path);
  }

  void onCodeChanged(String value) {
    if (codeFailure != null) setState(() => codeFailure = null);
  }

  void handleConfirmation(CodeState state) {
    if (!mounted || state is! CodeFailure) return;

    final fieldErrors = state.errors.errors.where(
      AuthenticationErrorMessageFormatter.isCodeError,
    );

    if (fieldErrors.isNotEmpty) {
      setState(() {
        codeFailure = AuthenticationErrorMessageFormatter.confirmationErrors(
          fieldErrors,
        );
      });
    }

    final remaining = state.errors.errors.where(
      (error) => !AuthenticationErrorMessageFormatter.isCodeError(error),
    );

    if (remaining.isNotEmpty || state.errors.errors.isEmpty) {
      context.showToast(
        variant: .error,
        title: 'Erro ao confirmar código',
        description: AuthenticationErrorMessageFormatter.confirmationErrors(
          remaining,
        ),
      );
    }
  }

  void handleResend(ResendEmailState state) {
    if (!mounted) return;

    switch (state) {
      case ResendEmailSuccess(:final userId):
        setState(() {
          _userId = userId;
          codeFailure = null;
          controller.clear();
        });
        context.showToast(
          variant: .success,
          title: 'Código reenviado',
          description: 'Enviamos um novo código para o seu e-mail.',
        );
      case ResendEmailFailure(:final errors):
        context.showToast(
          variant: .error,
          title: 'Erro ao reenviar código',
          description: AuthenticationErrorMessageFormatter.requestErrors(
            errors.errors,
          ),
        );
      case ResendEmailInitial() ||
          ResendEmailSubmitting() ||
          ResendEmailCooldown() ||
          ResendEmailReady():
        break;
    }
  }
}
