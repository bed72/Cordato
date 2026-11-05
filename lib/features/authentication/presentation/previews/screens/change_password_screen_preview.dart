import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/change_password_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/previews/fakes/authentication_recovery_preview_repository.dart';

@CordatoPreview(
  group: 'Authentication / Alterar senha',
  name: 'Formulário',
  size: cordatoPhonePreviewSize,
)
Widget previewChangePasswordScreen() => _previewChangePassword();

@CordatoPreview(
  group: 'Authentication / Alterar senha',
  name: 'Enviando',
  size: cordatoPhonePreviewSize,
)
Widget previewChangePasswordSubmitting() =>
    _previewChangePassword(submit: true, pending: true);

@CordatoPreview(
  group: 'Authentication / Alterar senha',
  name: 'Erros por campo',
  size: cordatoPhonePreviewSize,
)
Widget previewChangePasswordErrors() => _previewChangePassword(
  submit: true,
  errors: const ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '400',
        pointer: '/oldPassword',
        code: 'validation_invalid_old_password',
      ),
      ErrorEntity(
        status: '400',
        pointer: '/password',
        code: 'validation_length',
      ),
      ErrorEntity(
        status: '400',
        pointer: '/passwordConfirm',
        code: 'validation_values_mismatch',
      ),
    ],
  ),
);

@CordatoPreview(
  group: 'Authentication / Alterar senha',
  name: 'Falha ao sair',
  size: cordatoPhonePreviewSize,
)
Widget previewChangePasswordSignOutFailure() =>
    _previewChangePassword(submit: true, failSignOut: true);

Widget _previewChangePassword({
  bool submit = false,
  bool pending = false,
  bool failSignOut = false,
  ErrorsEntity? errors,
}) =>
    PreviewResourceWidget<
      ({ChangePasswordBloc bloc, Completer<void>? operation})
    >(
      create: () {
        final operation = pending ? Completer<void>() : null;
        final bloc = ChangePasswordBloc(
          repository: AuthenticationRecoveryPreviewRepository(
            changeOperation: operation?.future,
            changeErrors: errors,
            failSignOut: failSignOut,
          ),
        );
        if (submit) {
          bloc.add(
            const ChangePasswordSubmitted(
              oldPassword: 'OldPass1',
              password: 'NewPass1',
              passwordConfirm: 'NewPass1',
            ),
          );
        }
        return (bloc: bloc, operation: operation);
      },
      dispose: (resource) {
        unawaited(resource.bloc.close());
        resource.operation?.complete();
      },
      builder: (resource) => ChangePasswordScreen(
        bloc: resource.bloc,
        validation: const PasswordValidation(),
      ),
    );
