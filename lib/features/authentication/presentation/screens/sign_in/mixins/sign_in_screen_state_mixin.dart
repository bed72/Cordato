import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';

mixin SignInScreenStateMixin on State<SignInScreen> {
  SignInBloc get bloc => widget.bloc;

  final formKey = GlobalKey<FormSignInWidgetState>();

  void handleSignIn(SignInState state) {
    if (!mounted || bloc.isClosed || state is! SignInFailure) return;
    if (state case SignInFailure(:final errors) when errors.errors.isNotEmpty) {
      final remaining =
          formKey.currentState?.showErrors(errors.errors) ?? errors.errors;

      if (remaining.isNotEmpty) {
        context.showToast(
          variant: .error,
          title: remaining.first.title ?? 'Erro ao entrar',
          description: remaining
              .map(
                (error) =>
                    error.detail ?? 'Não foi possível entrar. Tente novamente.',
              )
              .join('\n'),
        );
      }
      return;
    }

    context.showToast(
      variant: .error,
      title: 'Erro ao entrar',
      description: 'Não foi possível entrar. Tente novamente.',
    );
  }

  void signIn() {
    if (!bloc.state.canSubmit) return;
    context.dismissKeyboard();
    formKey.currentState?.submit();
  }

  void submit(({String email, String password}) credentials) {
    if (!bloc.state.canSubmit) return;

    context.dismissKeyboard();

    bloc.add(
      SignInSubmittedEvent(
        email: credentials.email,
        password: credentials.password,
      ),
    );
  }
}
