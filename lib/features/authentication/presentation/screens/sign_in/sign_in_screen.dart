import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/form_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/button_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/widgets/app_bar_sign_in_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/mixins/sign_in_screen_state_mixin.dart';

final class const SignInScreen({
  super.key,
  required final SignInBloc bloc,
  required final EmailValidation emailValidation,
}) extends StatefulWidget {
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

final class _SignInScreenState extends State<SignInScreen>
    with SignInScreenStateMixin {
  @override
  Widget build(BuildContext context) => BlocConsumer<SignInBloc, SignInState>(
    bloc: widget.bloc,
    listener: (_, state) => handleSignIn(state),
    builder: (_, state) => Scaffold(
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
                        const HeaderWidget(
                          title: 'Que bom ter você por aqui',
                          description: 'Informe seu e-mail para receber um código de acesso',
                        ),
                        FormSignInWidget(
                          key: formKey,
                          onSubmit: submit,
                          enabled: state.canSubmit,
                          validation: widget.emailValidation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const .only(top: 16.0),
                child: ButtonSignInWidget(
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? signIn : null,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
