import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/widgets/email_field_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/mixins/resend_email_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/widgets/resend_email_cooldown_label_widget.dart';

final class const ResendEmailScreen({
  super.key,
  required final String email,
  required final ResendEmailBloc Function() bloc,
}) extends StatefulWidget {
  @override
  State<ResendEmailScreen> createState() => _ResendEmailScreenState();
}

final class _ResendEmailScreenState extends State<ResendEmailScreen>
    with ResendEmailVerificationScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ResendEmailBloc, ResendEmailState>(
      bloc: bloc,
      listener: (_, state) => handleResend(state),
      builder: (_, state) => Scaffold(
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
                          const HeaderWidget(
                            title: 'Verifique seu e-mail',
                            description: 'Confirme seu endereço usando o link de verificação',
                          ),
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
                ElevatedButtonWidget(
                  label: 'Reenviar',
                  isLoading: state.isSubmitting,
                  onTap: canResend ? resend : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
