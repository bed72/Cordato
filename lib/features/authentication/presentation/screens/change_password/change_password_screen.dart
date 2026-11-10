import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/widgets/password_field_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/mixins/change_password_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/widgets/change_password_signing_out_widget.dart';

final class const ChangePasswordScreen({
  required final ChangePasswordBloc bloc,
  required final PasswordValidation validation,
  super.key,
}) extends StatefulWidget {
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

final class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with ChangePasswordScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChangePasswordBloc, ChangePasswordState>(
      bloc: widget.bloc,
      listener: (_, state) => handleChange(state),
      builder: (_, state) => PopScope(
        canPop: state.canSubmit,
        child: switch (state) {
          ChangePasswordSignOutFailure() => ErrorScreen(
            title: 'Sua senha foi alterada',
            description: 'Precisamos encerrar sua sessão antes de continuar.',
            actionLabel: 'Tentar novamente',
            onAction: retrySignOut,
          ),
          ChangePasswordSigningOut() ||
          ChangePasswordSuccess() => const ChangePasswordSigningOutWidget(),
          _ => _buildForm(state),
        },
      ),
    );
  }

  Widget _buildForm(ChangePasswordState state) => Scaffold(
    appBar: AppBar(
      leadingWidth: 72.0,
      leading: Padding(
        padding: const .only(left: 16.0),
        child: BackButtonWidget(onPress: state.canSubmit ? goBack : null),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const .only(bottom: 24.0),
        child: Column(
          spacing: 16.0,
          crossAxisAlignment: .stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: .onDrag,
                padding: const .fromLTRB(16.0, 24.0, 16.0, 24.0),
                child: Column(
                  spacing: 24.0,
                  crossAxisAlignment: .stretch,
                  children: [
                    if (!context.isKeyboardVisible)
                      const HeaderWidget(
                        title: 'Altere sua senha',
                        description: 'Após trocar a senha, você precisará entrar novamente.',
                      ),
                    PasswordFieldWidget(
                      inputAction: .next,
                      label: 'Senha atual',
                      focusNode: currentFocus,
                      failure: currentFailure,
                      enabled: state.canSubmit,
                      controller: currentController,
                      hint: 'Digite sua senha atual',
                      onChanged: onCurrentChanged,
                      onEditingComplete: focusNewPassword,
                    ),
                    PasswordFieldWidget(
                      inputAction: .next,
                      label: 'Nova senha',
                      hint: 'Digite sua nova senha',
                      focusNode: passwordFocus,
                      failure: passwordFailure,
                      enabled: state.canSubmit,
                      controller: passwordController,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: onPasswordChanged,
                      onEditingComplete: focusConfirmation,
                    ),
                    PasswordFieldWidget(
                      inputAction: .send,
                      label: 'Confirmar nova senha',
                      hint: 'Confirme sua nova senha',
                      enabled: state.canSubmit,
                      failure: confirmationFailure,
                      focusNode: confirmationFocus,
                      controller: confirmationController,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: onConfirmationChanged,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const .symmetric(horizontal: 16.0),
              child: ElevatedButtonWidget(
                label: 'Salvar senha',
                isLoading: state.isBusy,
                onTap: state.canSubmit ? submit : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
