import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/commands/resend_email_command.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/mixins/resend_email_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/widgets/resend_email_header_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/widgets/resend_email_cooldown_label_widget.dart';

final class const ResendEmailScreen({
  super.key,
  required final String email,
  required final ResendEmailCommand command,
}) extends StatefulWidget {
  @override
  State<ResendEmailScreen> createState() => _ResendEmailScreenState();
}

final class _ResendEmailScreenState extends State<ResendEmailScreen>
    with ResendEmailVerificationScreenStateMixin {
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
                        const ResendEmailHeaderWidget(),
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
              ResendEmailCooldownLabelWidget(remaining: remaining),
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
                  onTap: remaining > .zero || widget.email.isEmpty
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
