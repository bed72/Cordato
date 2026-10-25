import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';

import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/callback_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/resend_email_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';

final authenticationModule = createModule(
  path: RouteEnum.app.path,
  register: (context) => context
    ..addLazySingleton<IAuthenticationRepository>(AuthenticationRepository.new)
    ..add(EmailValidation.new)
    ..add(PasswordValidation.new)
    ..add<SignUpBloc>(SignUpBloc.new)
    ..add<CallbackBloc>(CallbackBloc.new)
    ..add<ResendEmailBloc>(ResendEmailBloc.new)
    ..route(
      RouteEnum.authenticationConfirm.path,
      child: (_, state) => ResendEmailScreen(
        bloc: inject<ResendEmailBloc>,
        email: state.arguments as String? ?? '',
      ),
    )
    ..route(
      RouteEnum.authenticationSignIn.path,
      provide: (scope) => scope.addBloc<SignInBloc>(SignInBloc.new),
      child: (context, _) => SignInScreen(
        bloc: context.read<SignInBloc>(),
        emailValidation: inject<EmailValidation>(),
        passwordValidation: inject<PasswordValidation>(),
      ),
    )
    ..route(
      RouteEnum.authenticationSignUp.path,
      child: (_, _) => SignUpScreen(
        bloc: inject<SignUpBloc>,
        emailValidation: inject<EmailValidation>(),
        passwordValidation: inject<PasswordValidation>(),
      ),
    )
    ..route(
      RouteEnum.authenticationConfirmEmail.path,
      child: (_, state) => CallbackScreen(
        bloc: inject<CallbackBloc>,
        verificationUrl:
            switch (state.uri.queryParametersAll['verification_url']) {
              [final String url] => url,
              _ => null,
            },
      ),
    ),
);
