import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/presentation/screens/sign_in/commands/sign_in_command.dart';
import 'package:cordato/features/authentication/presentation/commands/sign_up_command.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/sign_up_screen.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/password_validation.dart';

const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://api.cordato.cloud/api/',
);

final _httpModule = createModule(
  register: (context) {
    context
      ..addInstance<String>(_baseUrl)
      ..addLazySingleton<IHttpClient>(
        () => HttpClient(
          dio: Dio(BaseOptions(baseUrl: _baseUrl))
            ..interceptors.add(HeadersInterceptor()),
        ),
      )
      ..addLazySingleton<IAuthenticationDataSource>(
        AuthenticationDataSource.new,
      )
      ..addLazySingleton<IAuthenticationRepository>(
        AuthenticationRepository.new,
      )
      ..addLazySingleton<IAuthenticationClient>(AuthenticationClient.new);
  },
);

final authenticationModule = createModule(
  path: RouteEnum.root.path,
  register: (context) {
    context
      ..module(_httpModule)
      ..add(EmailValidation.new)
      ..add(PasswordValidation.new)
      ..addLazySingleton<SignInCommand>(SignInCommand.new)
      ..addLazySingleton<SignUpCommand>(SignUpCommand.new)
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
        ),
      );
  },
);
