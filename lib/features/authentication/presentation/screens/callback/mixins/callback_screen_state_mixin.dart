import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/callback_screen.dart';

mixin CallbackScreenStateMixin on State<CallbackScreen> {
  int _revision = 0;
  bool _isRunning = false;
  int _startedRevision = -1;

  @override
  void initState() {
    super.initState();
    _scheduleConfirmation();
  }

  @override
  void didUpdateWidget(covariant CallbackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verificationUrl != widget.verificationUrl) {
      _revision++;
      _scheduleConfirmation();
    }
  }

  void _scheduleConfirmation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isRunning && _startedRevision != _revision) {
        unawaited(_confirm());
      }
    });
  }

  Future<void> _confirm() async {
    final revision = _revision;
    final url = widget.verificationUrl;
    EmailVerificationStatusEnum? status;

    _isRunning = true;
    _startedRevision = revision;

    try {
      if (url == null || url.isEmpty) {
        status = .invalid;
      } else {
        bool joinedSameLink = false;
        final command = widget.command.execute;

        if (command.isRunning.value) {
          joinedSameLink = command.results.value.paramData == url;
          final pendingResult = await command.runAsync();
          if (joinedSameLink) status = pendingResult;
        }

        if (!mounted || revision != _revision) return;
        if (!joinedSameLink) status = await command.runAsync(url);
      }
    } catch (_) {
      status = .failure;
    } finally {
      _isRunning = false;
      if (mounted && revision != _revision) _scheduleConfirmation();
    }

    if (!mounted || revision != _revision) return;

    switch (status ?? .failure) {
      case .success:
        context.showToast(
          variant: .success,
          title: 'E-mail confirmado',
          description: 'Entre na sua conta para continuar.',
        );
      case .invalid:
        context.showToast(
          variant: .error,
          title: 'Link inválido ou expirado',
          description: 'Solicite um novo e-mail de confirmação.',
        );
      case .failure:
        context.showToast(
          variant: .error,
          title: 'Não foi possível confirmar o e-mail',
          description:
              'Verifique sua conexão e tente novamente com o link recebido.',
        );
    }

    widget.onSignIn(context);
  }
}
