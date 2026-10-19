import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/sign_up_footer_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/button_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/app_bar_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/mixins/sign_in_screen_state_mixin.dart';

final class const SignInScreen({
  super.key,
  required final SignInBloc Function() bloc,
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
    return BlocConsumer<SignInBloc, SignInState>(
      bloc: bloc,
      listener: (_, state) => handleSignIn(state),
      builder: (_, state) => Scaffold(
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
                          const HeaderWidget(
                            title: 'Que bom ter você por aqui',
                            description: 'Entre com seu e-mail e senha',
                          ),
                          FormSignInWidget(
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
                ButtonSignInWidget(
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? signIn : null,
                ),
                const SignUpFooterWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
