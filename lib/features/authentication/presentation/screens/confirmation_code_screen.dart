import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/widgets/pin_field_widget.dart';
import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/widgets/app_bar_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/commands/confirmation_code_command.dart';
import 'package:cordato/features/authentication/presentation/widgets/resend_cooldown_label_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/header_confirmation_code_widget.dart';
import 'package:cordato/features/authentication/presentation/mixins/confirmation_code_screen_state_mixin.dart';

final class const ConfirmationCodeScreen({
  super.key,
  required final CodeValidation validation,
  required final MagicLinkCommand magicLinkcommand,
  required final ConfirmationCodeCommand confirmationCommand,
}) extends StatefulWidget {
  @override
  State<ConfirmationCodeScreen> createState() => _ConfirmationCodeScreenState();
}

final class _ConfirmationCodeScreenState extends State<ConfirmationCodeScreen>
    with WidgetsBindingObserver, ConfirmationCodeScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarMagicLinkWidget(),
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
                    padding: .symmetric(vertical: 24.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        spacing: 24.0,
                        crossAxisAlignment: .stretch,
                        children: [
                          HeaderConfirmationCodeWidget(),
                          PinFieldWidget(
                            controller: controller,
                            validation: widget.validation,
                            onCompleted: (_) => confirm(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                spacing: 4.0,
                crossAxisAlignment: .stretch,
                children: [
                  ResendCooldownLabelWidget(remaining: resendRemaining),
                  OutlineButtonWidget(
                    label: 'Reenviar',
                    isLoading: isResending,
                    onTap: isResending || resendRemaining > .zero
                        ? null
                        : resend,
                  ),
                  const SizedBox(height: 12.0),
                  ElevatedButtonWidget(
                    label: 'Confirmar',
                    isLoading: isConfirming,
                    onTap: isConfirming ? null : confirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
