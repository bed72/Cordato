import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show LocalStorage, Supabase;

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_storage_client.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/domain/enums/app_route.dart';

Module _createAppModule() => createModule(
  register: (c) {
    c
      ..module(coreModule)
      ..module(authenticationModule);
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sharedPreferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, (call) async {
          if (call.method == 'getAll') return <String, Object?>{};
          return null;
        });

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, null);
  });

  test('registers SupabaseStorageClient as LocalStorage', () {
    final bootstrap = bootstrapModule(_createAppModule());
    final route = bootstrap.routes.match(
      Uri.parse(AppRoute.authenticationMagicLink.path),
    )!;
    bootstrap.manager.enter('authentication-test', route.last.route.ownerTags);

    expect(
      bootstrap.injector.get<LocalStorage>(),
      isA<SupabaseStorageClient>(),
    );
    expect(
      bootstrap.injector.get<IAuthenticationClient>(),
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
    expect(route.last.route.path, AppRoute.authenticationMagicLink.path);

    bootstrap.manager.leave('authentication-test', route.last.route.ownerTags);
    bootstrap.manager.root.disposeRecursive();
  });

  test('matches the authentication callback deep link', () {
    final bootstrap = bootstrapModule(_createAppModule());

    final route = bootstrap.routes.match(
      Uri.parse(
        'trocado://authentication${AppRoute.authenticationCallback.path}'
        '?code=magic-link-code',
      ),
    );

    expect(route, isNotNull);
    expect(route!.last.route.path, AppRoute.authenticationCallback.path);

    bootstrap.manager.root.disposeRecursive();
  });
}
