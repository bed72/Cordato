import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';

import 'package:cordato/features/authentication/infrastructure/local/authentication_local_data_source.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_remote_data_source.dart';

import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/callback/commands/callback_command.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/callback_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/commands/sign_up_command.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/commands/sign_in_command.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/commands/resend_email_command.dart';

final authenticationModule = createModule(
  path: RouteEnum.root.path,
  register: (context) {
    context
      ..addLazySingleton<IAuthenticationRemoteDataSource>(
        AuthenticationRemoteDataSource.new,
      )
      ..addLazySingleton<IAuthenticationLocalDataSource>(
        AuthenticationLocalDataSource.new,
      )
      ..addLazySingleton<IAuthenticationRepository>(
        AuthenticationRepository.new,
      )
      ..add(EmailValidation.new)
      ..add(PasswordValidation.new)
      ..addLazySingleton<SignInCommand>(SignInCommand.new)
      ..addLazySingleton<SignUpCommand>(SignUpCommand.new)
      ..addLazySingleton<ResendEmailCommand>(ResendEmailCommand.new)
      ..addLazySingleton<CallbackCommand>(CallbackCommand.new)
      ..route(
        RouteEnum.authenticationConfirm.path,
        child: (_, state) => ResendEmailScreen(
          email: state.arguments as String? ?? '',
          command: inject<ResendEmailCommand>(),
        ),
      )
      ..route(
        RouteEnum.authenticationSignIn.path,
        child: (_, _) => SignInScreen(
          command: inject<SignInCommand>(),
          emailValidation: inject<EmailValidation>(),
          passwordValidation: inject<PasswordValidation>(),
          onCreateAccount: (BuildContext context) =>
              context.replace(RouteEnum.authenticationSignUp.path),
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
      );
  },
);
