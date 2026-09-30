import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/widgets/fields/email_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/commands/resend_email_verification_command.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm/widgets/header_confirm_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm/mixins/confirm_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm/widgets/resend_cooldown_label_widget.dart';

final class const ConfirmScreen({
  super.key,
  required final String email,
  required final ResendEmailVerificationCommand command,
}) extends StatefulWidget {
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

final class _ConfirmScreenState extends State<ConfirmScreen>
    with ConfirmScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarSignUpWidget(),
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
                        const HeaderConfirmWidget(),
                        EmailFieldWidget(
                          enabled: false,
                          label: 'E-mail',
                          initialValue: widget.email,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ResendCooldownLabelWidget(remaining: remaining),
              CommandBuilder<String, Either<ErrorsEntity, bool>?>(
                command: widget.command.execute,
                whileRunning: (_, _, _) => const ElevatedButtonWidget(
                  onTap: null,
                  isLoading: true,
                  label: 'Reenviar',
                ),
                onSuccess: (_, _) => ElevatedButtonWidget(
                  label: 'Reenviar',
                  onTap: remaining > Duration.zero || widget.email.isEmpty
                      ? null
                      : resend,
                ),
                onError: (_, _, _, _) => ElevatedButtonWidget(
                  label: 'Reenviar',
                  onTap: remaining > Duration.zero || widget.email.isEmpty
                      ? null
                      : resend,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
