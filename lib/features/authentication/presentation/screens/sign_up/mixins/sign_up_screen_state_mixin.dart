import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/form_sign_up_widget.dart';

mixin SignUpScreenStateMixin on State<SignUpScreen> {
  final formKey = GlobalKey<FormSignUpWidgetState>();

  @override
  void initState() {
    super.initState();
    widget.command.execute.results.addListener(_handleSignUp);
  }

  @override
  void dispose() {
    widget.command.execute.results.removeListener(_handleSignUp);
    super.dispose();
  }

  void _handleSignUp() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

    if (data.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao criar conta',
        description: 'Não foi possível criar sua conta. Tente novamente.',
      );
      return;
    }

    if (data.data case Left(:final value)) {
      final remaining =
          formKey.currentState?.showErrors(value.errors) ?? value.errors;
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
    } else if (data.data case Right(value: true)) {
      widget.onConfirm(context, data.paramData!.email);
    }
  }

  void signUp() {
    if (widget.command.execute.isRunning.value) return;
    context.dismissKeyboard();
    formKey.currentState?.submit();
  }

  void submit(({String email, String password}) credentials) {
    if (widget.command.execute.isRunning.value) return;
    context.dismissKeyboard();
    widget.command.execute.run(credentials);
  }
}
