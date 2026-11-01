import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/callback_screen.dart';

mixin CallbackScreenStateMixin on State<CallbackScreen> {
  late CallbackBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
    _confirm();
  }

  @override
  void didUpdateWidget(covariant CallbackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc != widget.bloc) {
      unawaited(bloc.close());
      bloc = widget.bloc();
      _confirm();
    } else if (oldWidget.token != widget.token) {
      _confirm();
    }
  }

  @override
  void dispose() {
    unawaited(bloc.close());
    super.dispose();
  }

  void _confirm() {
    bloc.add(CallbackRequestedEvent(token: widget.token));
  }

  void handleConfirmation(CallbackState state) {
    if (!mounted || bloc.isClosed) return;

    switch (state) {
      case CallbackInitial() || CallbackConfirming():
        return;
      case CallbackSuccess():
        context.showToast(
          variant: .success,
          title: 'E-mail confirmado',
          description: 'Entre na sua conta para continuar.',
        );
      case CallbackInvalid():
        context.showToast(
          variant: .error,
          title: 'Link inválido ou expirado',
          description: 'Solicite um novo e-mail de confirmação.',
        );
      case CallbackFailure():
        context.showToast(
          variant: .error,
          title: 'Não foi possível confirmar o e-mail',
          description:
              'Verifique sua conexão e tente novamente com o link recebido.',
        );
    }

    context
      ..navigate(RouteEnum.welcome.path)
      ..pushNamed(RouteEnum.authenticationSignIn.path);
  }
}
