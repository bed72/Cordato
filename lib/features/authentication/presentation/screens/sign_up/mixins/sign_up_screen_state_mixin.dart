import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/form_sign_up_widget.dart';

mixin SignUpScreenStateMixin on State<SignUpScreen> {
  late SignUpBloc bloc;
  final formKey = GlobalKey<FormSignUpWidgetState>();

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
  }

  @override
  void didUpdateWidget(covariant SignUpScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc == widget.bloc) return;
    unawaited(bloc.close());
    bloc = widget.bloc();
  }

  @override
  void dispose() {
    unawaited(bloc.close());
    super.dispose();
  }

  void handleSignUp(SignUpState state) {
    if (!mounted || bloc.isClosed) return;
    if (state case SignUpSuccess(:final email)) {
      context.replace(RouteEnum.authenticationConfirm.path, arguments: email);
      return;
    }

    if (state is SignUpFailure) {
      if (state case SignUpFailure(:final errors)
          when errors.errors.isNotEmpty) {
        final remaining =
            formKey.currentState?.showErrors(errors.errors) ?? errors.errors;
        if (remaining.isNotEmpty) {
          context.showToast(
            variant: .error,
            title: remaining.first.title ?? 'Erro ao criar conta',
            description: remaining
                .map(
                  (error) =>
                      error.detail ??
                      'Não foi possível criar sua conta. Tente novamente.',
                )
                .join('\n'),
          );
        }
        return;
      }
      context.showToast(
        variant: .error,
        title: 'Erro ao criar conta',
        description: 'Não foi possível criar sua conta. Tente novamente.',
      );
    }
  }

  void signUp() {
    if (!bloc.state.canSubmit) return;
    context.dismissKeyboard();
    formKey.currentState?.submit();
  }

  void submit(({String email, String password}) credentials) {
    if (!bloc.state.canSubmit) return;
    context.dismissKeyboard();
    bloc.add(
      SignUpSubmittedEvent(
        email: credentials.email,
        password: credentials.password,
      ),
    );
  }
}
