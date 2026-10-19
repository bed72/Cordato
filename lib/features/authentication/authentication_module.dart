import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/callback_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/commands/sign_up_command.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/commands/callback_command.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/commands/resend_email_command.dart';

final authenticationModule = createModule(
  path: RouteEnum.app.path,
  register: (context) => context
    ..add(EmailValidation.new)
    ..add(PasswordValidation.new)
    ..add<SignInBloc>(SignInBloc.new)
    ..addLazySingleton<SignUpCommand>(SignUpCommand.new)
    ..addLazySingleton<CallbackCommand>(CallbackCommand.new)
    ..addLazySingleton<ResendEmailCommand>(ResendEmailCommand.new)
    ..addLazySingleton<IAuthenticationRepository>(AuthenticationRepository.new)
    ..route(
      RouteEnum.authenticationConfirm.path,
      child: (_, state) => ResendEmailScreen(
        command: inject<ResendEmailCommand>(),
        email: state.arguments as String? ?? '',
      ),
    )
    ..route(
      RouteEnum.authenticationSignIn.path,
      child: (_, _) => SignInScreen(
        bloc: inject<SignInBloc>,
        emailValidation: inject<EmailValidation>(),
        passwordValidation: inject<PasswordValidation>(),
      ),
    )
    ..route(
      RouteEnum.authenticationSignUp.path,
      child: (_, _) => SignUpScreen(
        command: inject<SignUpCommand>(),
        emailValidation: inject<EmailValidation>(),
        passwordValidation: inject<PasswordValidation>(),
        onSignIn: (BuildContext context) =>
            context.replace(RouteEnum.authenticationSignIn.path),
        onConfirm: (BuildContext context, String email) => context.replace(
          RouteEnum.authenticationConfirm.path,
          arguments: email,
        ),
      ),
    )
    ..route(
      RouteEnum.authenticationConfirmEmail.path,
      child: (_, state) => CallbackScreen(
        verificationUrl:
            switch (state.uri.queryParametersAll['verification_url']) {
              [final String url] => url,
              _ => null,
            },
        command: inject<CallbackCommand>(),
        onSignIn: (BuildContext context) => context
          ..navigate(RouteEnum.welcome.path)
          ..pushNamed(RouteEnum.authenticationSignIn.path),
      ),
    ),
);
