import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/reset_password/reset_password_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/password_recovery_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_event.dart';

import 'package:cordato/features/authentication/presentation/previews/fakes/authentication_recovery_preview_repository.dart';

@CordatoPreview(
  group: 'Authentication / Recuperação',
  name: 'Solicitar link',
  size: cordatoPhonePreviewSize,
)
Widget previewPasswordRecoveryScreen() =>
    PreviewResourceWidget<PasswordRecoveryBloc>(
      create: () => PasswordRecoveryBloc(
        repository: const AuthenticationRecoveryPreviewRepository(),
      ),
      dispose: (bloc) => unawaited(bloc.close()),
      builder: (bloc) => PasswordRecoveryScreen(
        bloc: bloc,
        validation: const EmailValidation(),
      ),
    );

@CordatoPreview(
  group: 'Authentication / Recuperação',
  name: 'Confira seu e-mail',
  size: cordatoPhonePreviewSize,
)
Widget previewPasswordRecoverySentScreen() =>
    PreviewResourceWidget<PasswordRecoveryBloc>(
      create: () => PasswordRecoveryBloc(
        repository: const AuthenticationRecoveryPreviewRepository(),
      )..add(const PasswordRecoverySubmitted(email: 'pessoa@example.com')),
      dispose: (bloc) => unawaited(bloc.close()),
      builder: (bloc) => PasswordRecoveryScreen(
        bloc: bloc,
        validation: const EmailValidation(),
      ),
    );

@CordatoPreview(
  group: 'Authentication / Recuperação',
  name: 'Redefinir senha',
  size: cordatoPhonePreviewSize,
)
Widget previewResetPasswordScreen() => PreviewResourceWidget<ResetPasswordBloc>(
  create: () => ResetPasswordBloc(
    repository: const AuthenticationRecoveryPreviewRepository(),
  ),
  dispose: (bloc) => unawaited(bloc.close()),
  builder: (bloc) => ResetPasswordScreen(
    token: 'fixture.preview.token',
    bloc: bloc,
    validation: const PasswordValidation(),
  ),
);
