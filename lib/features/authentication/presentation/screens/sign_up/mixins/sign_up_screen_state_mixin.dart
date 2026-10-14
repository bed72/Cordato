import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
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
      if (data.error case CommandFailureException(:final errors)
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
    } else if (data.data == true) {
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
