import 'package:flutter_modular/flutter_modular.dart';
import 'package:dio/dio.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/interceptors/headers_interceptor.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/authentication/infrastructure/clients/authentication_client.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/presentation/screens/magic_link_screen.dart';
import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/screens/confirmation_code_screen.dart';
import 'package:cordato/features/authentication/presentation/commands/confirmation_code_command.dart';
import 'package:cordato/features/authentication/presentation/screens/authentication_callback_screen.dart';

const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://api.cordato.cloud/api/',
);

final _httpModule = createModule(
  register: (context) {
    context
      ..addLazySingleton<IHttpClient>(
        () => HttpClient(
          baseUrl: _baseUrl,
          dio: Dio()..interceptors.add(HeadersInterceptor()),
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
      ..add(CodeValidation.new)
      ..add(EmailValidation.new)
      ..addLazySingleton<MagicLinkCommand>(MagicLinkCommand.new)
      ..addLazySingleton<ConfirmationCodeCommand>(ConfirmationCodeCommand.new)
      ..route(
        RouteEnum.authenticationCallback.path,
        child: (_, _) => const AuthenticationCallbackScreen(),
      )
      ..route(
        RouteEnum.authenticationConfirmationCode.path,
        child: (_, _) => ConfirmationCodeScreen(
          validation: inject<CodeValidation>(),
          magicLinkcommand: inject<MagicLinkCommand>(),
          confirmationCommand: inject<ConfirmationCodeCommand>(),
        ),
      )
      ..route(
        RouteEnum.authenticationMagicLink.path,
        child: (_, _) => MagicLinkScreen(
          command: inject<MagicLinkCommand>(),
          validation: inject<EmailValidation>(),
          onConfirmationCode: (context) =>
              context.pushNamed(RouteEnum.authenticationConfirmationCode.path),
        ),
      );
  },
);
