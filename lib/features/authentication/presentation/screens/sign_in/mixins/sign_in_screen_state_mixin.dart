import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';

mixin SignInScreenStateMixin on State<SignInScreen> {
  final formKey = GlobalKey<FormSignInWidgetState>();

  @override
  void initState() {
    super.initState();
    widget.command.execute.results.addListener(_handleSignIn);
  }

  @override
  void dispose() {
    widget.command.execute.results.removeListener(_handleSignIn);
    super.dispose();
  }

  void _handleSignIn() {
    final data = widget.command.execute.results.value;
    if (!mounted || data.isRunning || data.paramData == null) return;

    if (!data.hasError) return;
    if (data.error case CommandFailureException(:final errors)
        when errors.errors.isNotEmpty) {
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
