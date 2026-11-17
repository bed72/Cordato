import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_state.dart';
import 'package:cordato/features/authentication/presentation/screens/code/widgets/pin_field_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/code/mixins/code_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/app_bar_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/widgets/resend_email_cooldown_label_widget.dart';

final class const CodeScreen({
  super.key,
  required final String email,
  required final String userId,
  required final CodeBloc codeBloc,
  required final CodeValidation validation,
  required final ResendEmailBloc resendBloc,
}) extends StatefulWidget {
  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

final class _CodeScreenState extends State<CodeScreen>
    with CodeScreenStateMixin {
  @override
  Widget build(BuildContext context) => BlocConsumer<CodeBloc, CodeState>(
    bloc: widget.codeBloc,
    listener: (_, state) => handleConfirmation(state),
    builder: (_, confirmation) =>
        BlocConsumer<ResendEmailBloc, ResendEmailState>(
          bloc: widget.resendBloc,
          listener: (_, state) => handleResend(state),
          builder: (_, resendState) {
            final enabled = confirmation.canSubmit && !resendState.isSubmitting;
            return Scaffold(
              appBar: const AppBarSignInWidget(),
              body: SafeArea(
                child: Padding(
                  padding: const .all(16.0),
                  child: Column(
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
                                HeaderWidget(
                                  title: 'Confirme seu código',
                                  description:
                                      'Enviamos um código para ${widget.email}',
                                ),
                                PinFieldWidget(
                                  controller: controller,
                                  enabled: enabled,
                                  failure: codeFailure,
                                  onChanged: onCodeChanged,
                                  onSubmit: confirm,
                                ),
                                Align(
                                  alignment: .centerLeft,
                                  child: LinkButtonWidget(
                                    label: 'Alterar e-mail',
                                    onTap: enabled ? changeEmail : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ResendEmailCooldownLabelWidget(
                        remaining: resendState.remaining,
                      ),
                      OutlineButtonWidget(
                        label: 'Reenviar',
                        isLoading: resendState.isSubmitting,
                        onTap: confirmation.canSubmit && resendState.canSubmit
                            ? resend
                            : null,
                      ),
                      const SizedBox(height: 12.0),
                      ElevatedButtonWidget(
                        label: 'Confirmar',
                        isLoading: confirmation.isSubmitting,
                        onTap: enabled ? confirm : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
  );
}
