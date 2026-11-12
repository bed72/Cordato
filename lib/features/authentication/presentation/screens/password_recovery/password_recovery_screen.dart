import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/widgets/password_recovery_sent_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/mixins/password_recovery_screen_state_mixin.dart';

final class const PasswordRecoveryScreen({
  super.key,
  required final PasswordRecoveryBloc bloc,
  required final EmailValidation validation,
}) extends StatefulWidget {
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

final class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen>
    with PasswordRecoveryScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      bloc: widget.bloc,
      listener: (_, state) => handleRecovery(state),
      builder: (_, state) => Scaffold(
        appBar: const AppBarSignUpWidget(),
        body: SafeArea(
          child: Padding(
            padding: const .fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: state.sentEmail != null
                ? PasswordRecoverySentWidget(
                    state: state,
                    controller: emailController,
                    emailFailure: emailFailure,
                    onEmailChanged: onEmailChanged,
                    onResend: resend,
                  )
                : Column(
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
                                  title: 'Recupere sua conta',
                                  description: 'Informe seu e-mail para receber um link de recuperação de senha.',
                                ),
                                EmailFieldWidget(
                                  label: 'E-mail',
                                  inputAction: .done,
                                  failure: emailFailure,
                                  enabled: state.canSubmit,
                                  controller: emailController,
                                  onChanged: onEmailChanged,
                                  onSubmitted: (_) => submit(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ElevatedButtonWidget(
                        label: 'Enviar',
                        isLoading: state.isSubmitting,
                        onTap: state.canSubmit ? submit : null,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
