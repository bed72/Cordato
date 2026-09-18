import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/screens/magic_link_screen.dart';

mixin MagicLinkScreenStateMixin on State<MagicLinkScreen> {
  String? failure;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.command.send.results.addListener(_handleSend);
  }

  @override
  void dispose() {
    widget.command.send.results.removeListener(_handleSend);
    controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final command = widget.command.send.results.value;
    if (!mounted || command.isRunning || command.paramData == null) return;

    if (command.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao enviar e-mail',
        description: 'Não foi possível enviar o e-mail. Tente novamente.',
      );
      return;
    }

    if (command.isSuccess) {
      final email = command.paramData;
      if (email == null) return;

      widget.command.beginConfirmation(email);
      controller.clear();
      widget.onConfirmationCode(context);
    }
  }

  void sendMagicLink() {
    context.dismissKeyboard();
    final validation = widget.validation(controller.text);

    switch (validation) {
      case Invalid(:final message):
        setState(() => failure = message);
      case Valid(:final value):
        setState(() => failure = null);
        widget.command.send.run(value);
    }
  }

  void clearFailure(String _) {
    if (failure != null) setState(() => failure = null);
  }
}
