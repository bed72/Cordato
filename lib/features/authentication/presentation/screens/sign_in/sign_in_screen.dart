import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/mixins/sign_in_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/commands/sign_in_command.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/header_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/app_bar_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/button_sign_in_builder_widget.dart';

final class const SignInScreen({
  super.key,
  required final SignInCommand command,
  required final EmailValidation emailValidation,
  required final PasswordValidation passwordValidation,
}) extends StatefulWidget {
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

final class _SignInScreenState extends State<SignInScreen>
    with SignInScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarSignInWidget(),
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
                        const HeaderSignInWidget(),
                        FormSignInWidget(
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
              ButtonSignInBuilderWidget(
                command: widget.command,
                onPressed: signIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
