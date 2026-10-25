import 'package:material_ui/material_ui.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/mixins/sign_up_screen_state_mixin.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/form_sign_up_widget.dart';
import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/sign_in_footer_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/button_sign_up_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';

final class const SignUpScreen({
  super.key,
  required final SignUpBloc Function() bloc,
  required final EmailValidation emailValidation,
  required final PasswordValidation passwordValidation,
}) extends StatefulWidget {
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

final class _SignUpScreenState extends State<SignUpScreen>
    with SignUpScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignUpBloc, SignUpState>(
      bloc: bloc,
      listener: (_, state) => handleSignUp(state),
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
                            title: 'Vamos lá',
                            description: 'Cadastre-se com seu e-mail e senha',
                          ),
                          FormSignUpWidget(
                            key: formKey,
                            onSubmit: submit,
                            enabled: state.canSubmit,
                            emailValidation: widget.emailValidation,
                            passwordValidation: widget.passwordValidation,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ButtonSignUpWidget(
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? signUp : null,
                ),
                const SignInFooterWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
