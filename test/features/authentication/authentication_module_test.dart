import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show LocalStorage, SupabaseClient;

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_storage_client.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/core/core_module.dart';

class _SupabaseClientMock extends Mock implements SupabaseClient {}

Module _createAppModule(SupabaseClient supabaseClient) => createModule(
  register: (c) {
    c
      ..module(coreModule)
      ..module(
        createAuthenticationModule(
          supabaseClient: supabaseClient,
          redirectUrl: 'com.cordato://login-callback',
        ),
      );
  },
);

void main() {
  test('registers SupabaseStorageClient as LocalStorage', () {
    final bootstrap = bootstrapModule(_createAppModule(_SupabaseClientMock()));
    final route = bootstrap.routes.match(
      Uri.parse('/authentication/magic-link'),
    )!;
    bootstrap.manager.enter('authentication-test', route.last.route.ownerTags);

    expect(
      bootstrap.injector.get<LocalStorage>(),
      isA<SupabaseStorageClient>(),
    );
    expect(
      bootstrap.injector.get<ISupabaseAuthenticationClient>(),
      isA<SupabaseAuthenticationClient>(),
    );
    expect(
      bootstrap.injector.get<IAuthenticationDataSource>(),
      isA<AuthenticationDataSource>(),
    );
    expect(
      bootstrap.injector.get<IAuthenticationRepository>(),
      isA<AuthenticationRepository>(),
    );
    expect(bootstrap.injector.get<MagicLinkCommand>(), isA<MagicLinkCommand>());
    expect(route.last.route.path, '/authentication/magic-link');

    bootstrap.manager.leave('authentication-test', route.last.route.ownerTags);
    bootstrap.manager.root.disposeRecursive();
  });
}
