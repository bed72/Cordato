import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/screens/confirmation_code_screen.dart';

mixin ConfirmationCodeScreenStateMixin
    on State<ConfirmationCodeScreen>, WidgetsBindingObserver {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();

  Timer? _timer;
  bool isResending = false;
  bool isConfirming = false;
  Duration resendRemaining = .zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.magicLinkcommand.resend.results.addListener(_handleResend);
    widget.confirmationCommand.confirm.results.addListener(_handleConfirmation);
    _resendCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.magicLinkcommand.resend.results.removeListener(_handleResend);
    widget.confirmationCommand.confirm.results.removeListener(
      _handleConfirmation,
    );
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == .resumed ? _resendCooldown() : _timer?.cancel();
  }

  void confirm() {
    if (isConfirming) return;

    context.dismissKeyboard();
    if (!(formKey.currentState?.validate() ?? false)) return;

    final email = widget.magicLinkcommand.email;
    if (email == null) {
      context.showToast(
        variant: .error,
        title: 'E-mail não informado',
        description: 'Informe seu e-mail para confirmar o código.',
      );
      return;
    }

    setState(() => isConfirming = true);
    widget.confirmationCommand.confirm.run((
      email: email,
      code: controller.text.trim(),
    ));
  }

  void resend() {
    if (isResending) return;

    final remaining = widget.magicLinkcommand.resendRemaining;
    if (remaining > .zero) {
      _resendCooldown();
      return;
    }

    final email = widget.magicLinkcommand.email;
    if (email == null) {
      context.showToast(
        variant: .error,
        title: 'E-mail não informado',
        description: 'Informe seu e-mail para solicitar um novo código.',
      );
      return;
    }

    setState(() => isResending = true);
    widget.magicLinkcommand.resend(email);
  }

  void _handleResend() {
    final command = widget.magicLinkcommand.resend.results.value;
    if (!mounted || !isResending || command.isRunning) return;

    if (command.hasError) {
      setState(() => isResending = false);
      context.showToast(
        variant: .error,
        title: 'Erro ao reenviar e-mail',
        description: 'Não foi possível enviar um novo código. Tente novamente.',
      );
      return;
    }

    if (command.isSuccess) {
      widget.magicLinkcommand.startCooldown();
      setState(() => isResending = false);
      _resendCooldown();
      context.showToast(
        variant: .success,
        title: 'Código reenviado',
        description: 'Enviamos um novo código para o seu e-mail.',
      );
    }
  }

  void _handleConfirmation() {
    final command = widget.confirmationCommand.confirm.results.value;
    if (!mounted || !isConfirming || command.isRunning) return;

    setState(() => isConfirming = false);
    if (command.hasError) {
      context.showToast(
        variant: .error,
        title: 'Código inválido',
        description: 'Não foi possível confirmar o código. Tente novamente.',
      );
    }
  }

  void _resendCooldown() {
    _timer?.cancel();
    _updateResendCooldown();

    if (resendRemaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateResendCooldown();
      });
    }
  }

  void _updateResendCooldown() {
    final remaining = widget.magicLinkcommand.resendRemaining;
    if (!mounted) return;

    setState(() => resendRemaining = remaining);
    if (remaining == .zero) _timer?.cancel();
  }
}
