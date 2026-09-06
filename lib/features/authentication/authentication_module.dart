import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

import 'package:cordato/features/core/domain/enums/route_enum.dart';

import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';

import 'package:cordato/features/authentication/presentation/screens/magic_link_screen.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/screens/authentication_callback_screen.dart';

const _supabaseRedirectUrl = String.fromEnvironment(
  'SUPABASE_REDIRECT_URL',
  defaultValue: 'trocado://authentication/callback',
);

final authenticationModule = createModule(
  path: RouteEnum.root.path,
  register: (context) {
    context
      ..add(EmailValidation.new)
      ..addInstance<String>(_supabaseRedirectUrl)
      ..addInstance<SupabaseClient>(Supabase.instance.client)
      ..addLazySingleton<MagicLinkCommand>(MagicLinkCommand.new)
      ..addLazySingleton<IAuthenticationDataSource>(
        AuthenticationDataSource.new,
      )
      ..addLazySingleton<IAuthenticationRepository>(
        AuthenticationRepository.new,
      )
      ..addLazySingleton<IAuthenticationClient>(
        SupabaseAuthenticationClient.new,
      )
      ..route(
        RouteEnum.authenticationCallback.path,
        child: (_, _) => const AuthenticationCallbackScreen(),
      )
      ..route(
        RouteEnum.authenticationMagicLink.path,
        child: (_, _) => MagicLinkScreen(
          command: inject<MagicLinkCommand>(),
          validation: inject<EmailValidation>(),
        ),
      );
  },
);
