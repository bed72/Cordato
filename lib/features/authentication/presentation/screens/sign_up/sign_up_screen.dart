import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/commands/sign_up_command.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/mixins/sign_up_screen_state_mixin.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/form_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/header_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/sign_in_footer_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/button_sign_up_builder_widget.dart';

final class const SignUpScreen({
  super.key,
  required final SignUpCommand command,
  required final EmailValidation emailValidation,
  required final PasswordValidation passwordValidation,
  required final ValueChanged<BuildContext> onSignIn,
  required final void Function(BuildContext context, String email) onConfirm,
}) extends StatefulWidget {
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

final class _SignUpScreenState extends State<SignUpScreen>
    with SignUpScreenStateMixin {
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
                        const HeaderSignUpWidget(),
                        FormSignUpWidget(
                          key: formKey,
                          onSubmit: submit,
                          emailValidation: widget.emailValidation,
                          passwordValidation: widget.passwordValidation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ButtonSignUpBuilderWidget(
                command: widget.command,
                onPressed: signUp,
              ),
              SignInFooterWidget(onSignIn: widget.onSignIn),
            ],
          ),
        ),
      ),
    );
  }
}
