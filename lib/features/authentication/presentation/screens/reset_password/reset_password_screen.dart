import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/widgets/password_field_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/mixins/reset_password_screen_state_mixin.dart';

final class const ResetPasswordScreen({
  super.key,
  required final String? token,
  required final ResetPasswordBloc bloc,
  required final PasswordValidation validation,
}) extends StatefulWidget {
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

final class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with ResetPasswordScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ResetPasswordBloc, ResetPasswordState>(
      bloc: widget.bloc,
      listener: (_, state) => handleReset(state),
      builder: (_, state) => state is ResetPasswordSessionFailure
          ? ErrorScreen(
              title: 'Não foi possível preparar a recuperação',
              description:
                  'Precisamos encerrar a sessão atual antes de continuar.',
              actionLabel: 'Tentar novamente',
              onAction: open,
            )
          : Scaffold(
              appBar: AppBar(
                leadingWidth: 72.0,
                leading: Padding(
                  padding: const .only(left: 16.0),
                  child: BackButtonWidget(
                    onPress: state.canSubmit ? goToSignIn : null,
                  ),
                ),
              ),
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
                                  title: 'Redefina sua senha',
                                  description: 'Escolha uma nova senha para acessar sua conta.',
                                ),
                                PasswordFieldWidget(
                                  hint: 'Nova senha',
                                  label: 'Nova senha',
                                  controller: passwordController,
                                  failure: passwordFailure,
                                  enabled: state.canSubmit,
                                  inputAction: .next,
                                  onEditingComplete: focusConfirmation,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  onChanged: onPasswordChanged,
                                ),
                                PasswordFieldWidget(
                                  inputAction: .done,
                                  focusNode: confirmationFocus,
                                  enabled: state.canSubmit,
                                  failure: confirmationFailure,
                                  hint: 'Confirme a nova senha',
                                  label: 'Confirmar nova senha',
                                  controller: confirmationController,
                                  onSubmitted: (_) => submit(),
                                  onChanged: onConfirmationChanged,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ElevatedButtonWidget(
                        label: 'Redefinir senha',
                        isLoading:
                            state.isSubmitting ||
                            state is ResetPasswordPreparing,
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
