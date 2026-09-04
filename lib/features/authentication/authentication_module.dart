import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show LocalStorage, Supabase, SupabaseClient;

import 'data/repositories/authentication_repository.dart';
import 'domain/repositories/interface_authentication_repository.dart';
import 'infrastructure/clients/supabase_authentication_client.dart';
import 'infrastructure/clients/supabase_storage_client.dart';
import 'infrastructure/remoto/authentication_data_source.dart';
import 'presentation/commands/magic_link_command.dart';
import 'presentation/screens/authentication_callback_screen.dart';
import 'presentation/screens/magic_link_screen.dart';

const _supabaseRedirectUrl = String.fromEnvironment(
  'SUPABASE_REDIRECT_URL',
  defaultValue: 'trocado://authentication/callback',
);

final authenticationModule = createModule(
  path: '/',
  register: (context) {
    context
      ..addInstance<String>(_supabaseRedirectUrl)
      ..addInstance<SupabaseClient>(Supabase.instance.client)
      ..addLazySingleton<LocalStorage>(SupabaseStorageClient.new)
      ..addLazySingleton<IAuthenticationClient>(
        SupabaseAuthenticationClient.new,
      )
      ..addLazySingleton<IAuthenticationDataSource>(
        AuthenticationDataSource.new,
      )
      ..addLazySingleton<IAuthenticationRepository>(
        AuthenticationRepository.new,
      )
      ..addLazySingleton<MagicLinkCommand>(MagicLinkCommand.new)
      ..route(
        '/authentication/magic-link',
        child: (context, _) =>
            MagicLinkScreen(command: inject<MagicLinkCommand>()),
      )
      ..route(
        '/callback',
        child: (_, _) => const AuthenticationCallbackScreen(),
      );
  },
);
