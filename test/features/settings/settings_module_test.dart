import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

void main() {
  test('Settings registers both local destinations without authentication', () {
    final boot = bootstrapModule(
      createModule(register: (context) => context.module(settingsModule)),
    );
    addTearDown(boot.injector.dispose);

    final matches = boot.routes.match(
      Uri.parse(RouteEnum.settingsSupport.path),
    );

    expect(
      RouteEnum.authenticatedPaths(),
      isNot(contains(RouteEnum.settingsSupport.path)),
    );
    expect(matches, hasLength(1));
    expect(matches!.single.route.provide, isNull);
    expect(RouteEnum.settings.authenticated, isFalse);
    expect(RouteEnum.settingsSupport.authenticated, isFalse);
    expect(RouteEnum.settingsSupport.path, '/settings/support');
    expect(matches.single.route.path, RouteEnum.settingsSupport.path);
    expect(
      boot.routes.routes.map((route) => route.path),
      unorderedEquals([
        RouteEnum.settings.path,
        RouteEnum.settingsSupport.path,
      ]),
    );
  });
}
