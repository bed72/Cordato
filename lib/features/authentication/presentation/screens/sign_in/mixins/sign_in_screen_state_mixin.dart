import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/code/arguments/code_arguments.dart';
import 'package:cordato/features/authentication/presentation/formatters/authentication_error_message_formatter.dart';

mixin SignInScreenStateMixin on State<SignInScreen> {
  final formKey = GlobalKey<FormSignInWidgetState>();
  String? _submittedEmail;

  void handleSignIn(SignInState state) {
    if (!mounted || widget.bloc.isClosed) return;

    switch (state) {
      case SignInSuccess(:final userId):
        final email = _submittedEmail;
        if (email == null) return;

        context.replace(
          RouteEnum.authenticationConfirm.path,
          arguments: CodeArguments(email: email, userId: userId),
        );
      case SignInFailure(:final errors):
        final remaining =
            formKey.currentState?.showErrors(errors.errors) ?? errors.errors;

        if (remaining.isNotEmpty || errors.errors.isEmpty) {
          context.showToast(
            variant: .error,
            title: 'Erro ao enviar código',
            description: AuthenticationErrorMessageFormatter.requestErrors(
              remaining,
            ),
          );
        }
      case SignInInitial() || SignInSubmitting():
        break;
    }
  }

  void signIn() {
    if (!widget.bloc.state.canSubmit) return;

    context.dismissKeyboard();
    formKey.currentState?.submit();
  }

  void submit(String email) {
    if (!widget.bloc.state.canSubmit) return;

    context.dismissKeyboard();
    _submittedEmail = email;
    widget.bloc.add(SignInSubmittedEvent(email: email));
  }
}
