import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'package:cordato/features/core/domain/enums/route_enum.dart';

import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/data/repositories/authentication_repository.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/infrastructure/remoto/authentication_data_source.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_authentication_client.dart';

Module _createAppModule() => createModule(
  register: (context) {
    context.module(authenticationModule);
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

  test('registers the authentication dependencies', () {
    final bootstrap = bootstrapModule(_createAppModule());
    final route = bootstrap.routes.match(
      Uri.parse(RouteEnum.authenticationMagicLink.path),
    )!;
    bootstrap.manager.enter('authentication-test', route.last.route.ownerTags);

    expect(route.last.route.path, RouteEnum.authenticationMagicLink.path);
    expect(bootstrap.injector.get<MagicLinkCommand>(), isA<MagicLinkCommand>());
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

    bootstrap.manager.leave('authentication-test', route.last.route.ownerTags);
    bootstrap.manager.root.disposeRecursive();
  });

  test('matches the authentication callback deep link', () {
    final bootstrap = bootstrapModule(_createAppModule());

    final route = bootstrap.routes.match(
      Uri.parse(
        'trocado://authentication${RouteEnum.authenticationCallback.path}'
        '?code=magic-link-code',
      ),
    );

    expect(route, isNotNull);
    expect(route!.last.route.path, RouteEnum.authenticationCallback.path);

    bootstrap.manager.root.disposeRecursive();
  });
}
