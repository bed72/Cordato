import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

mixin ResendEmailVerificationScreenStateMixin on State<ResendEmailScreen> {
  static const _cooldown = Duration(seconds: 60);

  Timer? _timer;
  late DateTime _cooldownEndsAt;
  Duration remaining = _cooldown;

  @override
  void initState() {
    super.initState();
    widget.command.execute.results.addListener(_handleResend);
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.command.execute.results.removeListener(_handleResend);
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldownEndsAt = DateTime.now().add(_cooldown);
    setState(() => remaining = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final timeLeft = _cooldownEndsAt.difference(DateTime.now());
      setState(
        () => remaining = timeLeft.isNegative ? Duration.zero : timeLeft,
      );
      if (remaining == Duration.zero) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void resend() {
    if (remaining > Duration.zero ||
        widget.email.isEmpty ||
        widget.command.execute.isRunning.value) {
      return;
    }
    widget.command.execute.run(widget.email);
  }

  void _handleResend() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

    if (data.hasError) {
      if (data.error case CommandFailureException(:final errors)
          when errors.errors.isNotEmpty) {
        context.showToast(
          variant: .error,
          title: errors.errors.first.title ?? 'Erro ao reenviar e-mail',
          description: errors.errors
              .map(
                (error) =>
                    error.detail ?? 'Não foi possível reenviar o e-mail.',
              )
              .join('\n'),
        );
        return;
      }
      context.showToast(
        variant: .error,
        title: 'Erro ao reenviar e-mail',
        description: 'Não foi possível reenviar o e-mail. Tente novamente.',
      );
    } else if (data.data == true) {
      _startCooldown();
      context.showToast(
        title: 'E-mail reenviado',
        description: 'Confira sua caixa de entrada para confirmar seu e-mail.',
      );
    }
  }
}
