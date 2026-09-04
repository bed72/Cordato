import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/core/presentation/validators/validation.dart';

import 'package:cordato/features/authentication/presentation/widgets/field_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/button_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/header_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/app_bar_magic_link_widget.dart';

final class MagicLinkScreen extends StatefulWidget {
  final MagicLinkCommand command;

  const MagicLinkScreen({super.key, required this.command});

  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

final class _MagicLinkScreenState extends State<MagicLinkScreen> {
  String? _emailFailure;

  final _emailController = TextEditingController();
  final _emailValidation = const EmailValidation();

  @override
  void initState() {
    super.initState();
    widget.command.send.results.addListener(_handleSendResult);
  }

  @override
  void dispose() {
    widget.command.send.results.removeListener(_handleSendResult);
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendResult() {
    final result = widget.command.send.results.value;
    if (!mounted || result.isRunning || result.paramData == null) return;

    if (result.hasError) {
      context.showToast(
        variant: .error,
        title: 'Erro ao enviar e-mail',
        description: 'Não foi possível enviar o e-mail. Tente novamente.',
      );
      return;
    }

    if (result.isSuccess) {
      context.showToast(
        variant: .success,
        title: 'E-mail enviado',
        description: 'Enviamos um link de acesso para o seu e-mail.',
      );
    }
  }

  void _sendMagicLink() {
    context.dismissKeyboard();
    final validation = _emailValidation(_emailController.text);

    switch (validation) {
      case Invalid(:final message):
        setState(() => _emailFailure = message);
      case Valid(:final value):
        setState(() => _emailFailure = null);
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
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const .symmetric(vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        const HeaderMagicLinkWidget(),
                        const SizedBox(height: 24),
                        FieldMagicLinkWidget(
                          failure: _emailFailure,
                          controller: _emailController,
                          onSubmitted: (_) => _sendMagicLink(),
                          onChanged: (_) {
                            if (_emailFailure != null) {
                              setState(() => _emailFailure = null);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              CommandBuilder<String, void>(
                command: widget.command.send,
                whileRunning: (context, _, _) => const ButtonMagicLinkWidget(
                  isLoading: true,
                  onPressed: null,
                ),
                onSuccess: (context, _) => ButtonMagicLinkWidget(
                  isLoading: false,
                  onPressed: _sendMagicLink,
                ),
                onError: (context, error, _, _) => ButtonMagicLinkWidget(
                  isLoading: false,
                  onPressed: _sendMagicLink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
