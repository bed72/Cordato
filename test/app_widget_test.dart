import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/app_widget.dart';
import 'package:cordato/features/core/domain/enums/route_enum.dart';

void main() {
  testWidgets('navigates to dashboard after authentication', (tester) async {
    final authenticationEvents = StreamController<void>();
    addTearDown(authenticationEvents.close);
    final module = createModule(
      register: (context) {
        context
          ..route(
            RouteEnum.welcome.path,
            child: (_, _) => const Text('Boas-vindas'),
          )
          ..route(
            RouteEnum.dashboard.path,
            child: (_, _) => const Text('Dashboard'),
          );
      },
    );

    await tester.pumpWidget(
      ModularApp(
        module: module,
        initialRoute: RouteEnum.welcome.path,
        child: AppWidget(events: authenticationEvents.stream),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boas-vindas'), findsOneWidget);

    authenticationEvents.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Boas-vindas'), findsNothing);
  });
}
