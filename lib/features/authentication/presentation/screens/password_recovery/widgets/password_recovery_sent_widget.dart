import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/widgets/resend_email_cooldown_label_widget.dart';

final class const PasswordRecoverySentWidget({
  super.key,
  required final VoidCallback onResend,
  required final PasswordRecoveryState state,
  required final TextEditingController controller,
  required final ValueChanged<String> onEmailChanged,
  final String? emailFailure,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16.0,
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const .symmetric(vertical: 16.0),
              child: Column(
                spacing: 24.0,
                crossAxisAlignment: .stretch,
                children: [
                  const HeaderWidget(
                    title: 'Confira seu e-mail',
                    description:
                        'Enviamos as instruções para redefinir sua senha.',
                  ),
                  EmailFieldWidget(
                    label: 'E-mail',
                    failure: emailFailure,
                    controller: controller,
                    enabled: state.canSubmit,
                    inputAction: .done,
                    onChanged: onEmailChanged,
                    onSubmitted: (_) => onResend(),
                  ),
                ],
              ),
            ),
          ),
        ),
        ResendEmailCooldownLabelWidget(remaining: state.remaining),
        ElevatedButtonWidget(
          label: 'Reenviar',
          isLoading: state.isSubmitting,
          onTap: state.canSubmit ? onResend : null,
        ),
      ],
    );
  }
}
