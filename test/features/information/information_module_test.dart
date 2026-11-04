import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/information/information_module.dart';

void main() {
  group('Information public route catalog', () {
    late ModularBootstrap boot;

    setUp(() {
      boot = bootstrapModule(informationModule);
      addTearDown(boot.injector.dispose);
    });

    const destinations = {
      RouteEnum.informationTerms: '/information/terms',
      RouteEnum.informationPrivacy: '/information/privacy',
      RouteEnum.informationHelp: '/information/help',
    };

    test('registers only the three information destinations', () {
      expect(
        boot.routes.routes.map((route) => route.path),
        unorderedEquals(destinations.values),
      );
    });

    for (final entry in destinations.entries) {
      test(
        '${entry.value} resolves without authentication or dependencies',
        () {
          final matches = boot.routes.match(Uri.parse(entry.value));

          expect(entry.key.path, entry.value);
          expect(entry.key.authenticated, isFalse);
          expect(RouteEnum.authenticatedPaths(), isNot(contains(entry.value)));
          expect(matches, hasLength(1));

          final route = matches!.single.route;
          expect(route.path, entry.value);
          expect(route.guards, isEmpty);
          expect(route.ownerTags, isEmpty);
          expect(route.provide, isNull);
        },
      );
    }
  });
}
