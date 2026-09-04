import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/presentation/widgets/redirect_widget.dart';

void main() {
  testWidgets('redirects after authentication completes', (tester) async {
    final authenticationEvents = StreamController<void>();
    addTearDown(authenticationEvents.close);
    var redirects = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: RedirectWidget(
          events: authenticationEvents.stream,
          onAuthenticated: () => redirects++,
          child: const Text('Conteúdo'),
        ),
      ),
    );

    authenticationEvents.add(null);
    await tester.pump();

    expect(redirects, 1);
    expect(find.text('Conteúdo'), findsOneWidget);
  });
}
