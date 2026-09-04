import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';

import 'package:cordato/features/authentication/presentation/widgets/field_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/header_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/app_bar_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/button_magic_link_builder_widget.dart';

final class MagicLinkScreen extends StatefulWidget {
  final MagicLinkCommand command;
  final EmailValidation validation;

  const MagicLinkScreen({
    super.key,
    required this.command,
    required this.validation,
  });

  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

final class _MagicLinkScreenState extends State<MagicLinkScreen> {
  String? _failure;

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    widget.command.send.results.addListener(_handleSend);
  }

  @override
  void dispose() {
    widget.command.send.results.removeListener(_handleSend);
    _controller.dispose();
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
      context.showToast(
        variant: .success,
        title: 'E-mail enviado',
        description: 'Enviamos um link de acesso para o seu e-mail.',
      );
    }
  }

  void _sendMagicLink() {
    context.dismissKeyboard();
    final validation = widget.validation(_controller.text);

    switch (validation) {
      case Invalid(:final message):
        setState(() => _failure = message);
      case Valid(:final value):
        setState(() => _failure = null);
        widget.command.send.run(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarMagicLinkWidget(),
      body: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: Column(
            spacing: 16.0,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const .symmetric(vertical: 24.0),
                    child: Column(
                      spacing: 24.0,
                      crossAxisAlignment: .stretch,
                      children: [
                        const HeaderMagicLinkWidget(),
                        FieldMagicLinkWidget(
                          failure: _failure,
                          controller: _controller,
                          onSubmitted: (_) => _sendMagicLink(),
                          onChanged: (_) {
                            if (_failure != null) {
                              setState(() => _failure = null);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ButtonMagicLinkBuilderWidget(
                command: widget.command,
                onPressed: _sendMagicLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
