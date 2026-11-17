import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/code/code_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/previews/fakes/authentication_preview_repository.dart';

@CordatoPreview(
  group: 'Authentication / E-mail',
  name: 'Solicitar código',
  size: cordatoPhonePreviewSize,
)
Widget previewRequestCode() => _requestPreview();

@CordatoPreview(
  group: 'Authentication / E-mail',
  name: 'Enviando',
  size: cordatoPhonePreviewSize,
)
Widget previewRequestCodePending() => _requestPreview(pending: true);

Widget _requestPreview({bool pending = false}) =>
    PreviewResourceWidget<({SignInBloc bloc, Completer<String>? operation})>(
      create: () {
        final operation = pending ? Completer<String>() : null;
        final bloc = SignInBloc(
          repository: AuthenticationPreviewRepository(
            requestOperation: operation?.future,
          ),
        );
        if (pending) {
          bloc.add(const SignInSubmittedEvent(email: 'pessoa@example.com'));
        }
        return (bloc: bloc, operation: operation);
      },
      dispose: (resource) {
        unawaited(resource.bloc.close());
        resource.operation?.complete('preview-user');
      },
      builder: (resource) => SignInScreen(
        bloc: resource.bloc,
        emailValidation: const EmailValidation(),
      ),
    );

@CordatoPreview(
  group: 'Authentication / Código',
  name: 'Confirmação',
  size: cordatoPhonePreviewSize,
)
Widget previewCode() => _confirmationPreview();

@CordatoPreview(
  group: 'Authentication / Código',
  name: 'Confirmando',
  size: cordatoPhonePreviewSize,
)
Widget previewCodePending() => _confirmationPreview(pending: true);

@CordatoPreview(
  group: 'Authentication / Código',
  name: 'Código inválido',
  size: cordatoPhonePreviewSize,
)
Widget previewCodeFailure() => _confirmationPreview(fail: true);

Widget _confirmationPreview({bool pending = false, bool fail = false}) =>
    PreviewResourceWidget<
      ({CodeBloc bloc, ResendEmailBloc resend, Completer<void>? operation})
    >(
      create: () {
        final operation = pending ? Completer<void>() : null;
        final repository = AuthenticationPreviewRepository(
          confirmationOperation: operation?.future,
          confirmationFailure: fail
              ? const ErrorsEntity(
                  errors: [
                    ErrorEntity(status: '401', code: 'user_invalid_token'),
                  ],
                )
              : null,
        );
        final bloc = CodeBloc(repository: repository);
        if (pending || fail) {
          bloc.add(
            const CodeSubmittedEvent(userId: 'preview-user', code: '012345'),
          );
        }
        return (
          bloc: bloc,
          resend: ResendEmailBloc(repository: repository),
          operation: operation,
        );
      },
      dispose: (resource) {
        unawaited(resource.bloc.close());
        unawaited(resource.resend.close());
        resource.operation?.complete();
      },
      builder: (resource) => CodeScreen(
        email: 'pessoa@example.com',
        userId: 'preview-user',
        codeBloc: resource.bloc,
        resendBloc: resource.resend,
        validation: const CodeValidation(),
      ),
    );
