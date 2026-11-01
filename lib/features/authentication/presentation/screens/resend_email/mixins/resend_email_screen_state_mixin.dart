import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';

import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';

mixin ResendEmailVerificationScreenStateMixin on State<ResendEmailScreen> {
  late ResendEmailBloc bloc;

  Duration get remaining => bloc.state.remaining;

  bool get canResend => widget.email.isNotEmpty && bloc.state.canSubmit;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
    bloc.add(ResendEmailStartedEvent(email: widget.email));
  }

  @override
  void didUpdateWidget(covariant ResendEmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc && oldWidget.email == widget.email) {
      return;
    }
    unawaited(bloc.close());
    bloc = widget.bloc();
    bloc.add(ResendEmailStartedEvent(email: widget.email));
  }

  @override
  void dispose() {
    unawaited(bloc.close());
    super.dispose();
  }

  void resend() {
    if (!canResend) return;
    bloc.add(ResendEmailSubmittedEvent(email: widget.email));
  }

  void handleResend(ResendEmailState state) {
    if (!mounted || bloc.isClosed) return;

    if (state is ResendEmailFailure) {
      if (state.isInitialRequest) {
        context.showToast(
          variant: .error,
          title: 'Conta criada',
          description: 'Não foi possível enviar o e-mail de verificação. Toque em Reenviar para tentar novamente.',
        );
        return;
      }
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
      context.showToast(
        title: state.isInitialRequest ? 'E-mail enviado' : 'E-mail reenviado',
        description: 'Confira sua caixa de entrada para confirmar seu e-mail.',
      );
    }
  }
}
