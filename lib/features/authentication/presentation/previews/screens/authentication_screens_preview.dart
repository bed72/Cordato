import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';

import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/commands/confirmation_code_command.dart';

import 'package:cordato/features/authentication/presentation/screens/magic_link_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/confirmation_code_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/authentication_callback_screen.dart';

import 'package:cordato/features/authentication/presentation/previews/fakes/authentication_preview_repository.dart';

@CordatoPreview(
  name: 'Magic link',
  group: 'Autenticação / Telas',
  size: cordatoPhonePreviewSize,
)
Widget previewMagicLinkScreen() => PreviewResourceWidget<MagicLinkCommand>(
  create: () =>
      MagicLinkCommand(repository: const AuthenticationPreviewRepository()),
  dispose: (command) => command.dispose(),
  builder: (command) => MagicLinkScreen(
    command: command,
    onConfirmationCode: (_) {},
    validation: const EmailValidation(),
  ),
);

@CordatoPreview(
  group: 'Autenticação / Telas',
  name: 'Código de confirmação',
  size: cordatoPhonePreviewSize,
)
Widget previewConfirmationCodeScreen() =>
    PreviewResourceWidget<
      ({MagicLinkCommand magicLink, ConfirmationCodeCommand confirmation})
    >(
      create: () {
        const repository = AuthenticationPreviewRepository();
        final magicLink = MagicLinkCommand(
          repository: repository,
          now: () => DateTime(2026, 9, 13, 12),
        )..beginConfirmation('gabriel@cordato.app');

        return (
          magicLink: magicLink,
          confirmation: ConfirmationCodeCommand(repository: repository),
        );
      },
      dispose: (commands) {
        commands.magicLink.dispose();
        commands.confirmation.dispose();
      },
      builder: (commands) => ConfirmationCodeScreen(
        validation: const CodeValidation(),
        magicLinkcommand: commands.magicLink,
        confirmationCommand: commands.confirmation,
      ),
    );

@CordatoPreview(
  name: 'Validando acesso',
  group: 'Autenticação / Telas',
  size: cordatoPhonePreviewSize,
)
Widget previewAuthenticationCallbackScreen() =>
    const AuthenticationCallbackScreen();
