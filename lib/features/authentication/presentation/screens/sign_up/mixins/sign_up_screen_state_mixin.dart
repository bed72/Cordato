import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/form_sign_up_widget.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

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
      final error = value.errors.firstOrNull;
      context.showToast(
        variant: .error,
        title: error?.title ?? 'Erro ao criar conta',
        description:
            error?.detail ??
            'Não foi possível criar sua conta. Tente novamente.',
      );
    } else if (data.data case Right(value: true)) {
      context.showToast(
        variant: .success,
        title: 'Conta criada',
        description: 'Sua conta foi criada com sucesso.',
      );
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
