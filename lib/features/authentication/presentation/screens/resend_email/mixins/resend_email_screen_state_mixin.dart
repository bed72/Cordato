import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';

import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';

mixin ResendEmailVerificationScreenStateMixin on State<ResendEmailScreen> {
  static const _cooldown = Duration(seconds: 60);

  Timer? _timer;
  late ResendEmailBloc bloc;
  Duration remaining = Duration.zero;

  bool get canResend =>
      remaining == .zero && widget.email.isNotEmpty && bloc.state.canSubmit;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
  }

  @override
  void didUpdateWidget(covariant ResendEmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) return;
    unawaited(bloc.close());
    bloc = widget.bloc();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(bloc.close());
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();

    setState(() => remaining = _cooldown);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final timeLeft = _cooldown - Duration(seconds: timer.tick);
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
    if (!canResend) return;
    bloc.add(ResendEmailSubmittedEvent(email: widget.email));
  }

  void handleResend(ResendEmailState state) {
    if (!mounted || bloc.isClosed) return;

    if (state is ResendEmailFailure) {
      if (state case ResendEmailFailure(:final errors)
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
    } else if (state is ResendEmailSuccess) {
      _startCooldown();
      context.showToast(
        title: 'E-mail reenviado',
        description: 'Confira sua caixa de entrada para confirmar seu e-mail.',
      );
    }
  }
}
