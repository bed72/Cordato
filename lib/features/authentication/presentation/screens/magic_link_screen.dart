import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/widgets/magic_link_email_field.dart';
import 'package:cordato/features/authentication/presentation/widgets/magic_link_header.dart';
import 'package:cordato/features/authentication/presentation/widgets/magic_link_message.dart';
import 'package:cordato/features/authentication/presentation/widgets/magic_link_submit_button.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:material_ui/material_ui.dart';
import 'package:command_it/command_it.dart';

final class MagicLinkScreen extends StatefulWidget {
  final MagicLinkCommand command;

  const MagicLinkScreen({super.key, required this.command});

  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

final class _MagicLinkScreenState extends State<MagicLinkScreen> {
  final _emailController = TextEditingController();
  String? _emailFailure;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendMagicLink() {
    final email = _emailController.text.trim();
    final failure = _validateEmail(email);
    if (failure != null) {
      setState(() => _emailFailure = failure);
      return;
    }

    setState(() => _emailFailure = null);
    widget.command.send.run(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const .all(24),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const MagicLinkHeader(),
                const SizedBox(height: 24),
                MagicLinkEmailField(
                  controller: _emailController,
                  onSubmitted: (_) => _sendMagicLink(),
                  failure: _emailFailure,
                  onChanged: (_) {
                    if (_emailFailure != null) {
                      setState(() => _emailFailure = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                CommandBuilder<String, void>(
                  command: widget.command.send,
                  whileRunning: (context, _, _) => const MagicLinkSubmitButton(
                    isLoading: true,
                    onPressed: null,
                  ),
                  onSuccess: (context, email) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MagicLinkSubmitButton(
                        isLoading: false,
                        onPressed: _sendMagicLink,
                      ),
                      if (email != null) ...[
                        const SizedBox(height: 16),
                        MagicLinkMessage(
                          message: 'Link enviado para $email.',
                          color: context.colors.primary,
                        ),
                      ],
                    ],
                  ),
                  onError: (context, error, _, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MagicLinkSubmitButton(
                        isLoading: false,
                        onPressed: _sendMagicLink,
                      ),
                      const SizedBox(height: 16),
                      MagicLinkMessage(
                        message: error.toString(),
                        color: context.colors.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Informe seu email.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Informe um email válido.';
    }
    return null;
  }
}
